#!/usr/bin/env python3
import asyncio
import json
import os
import time
from datetime import datetime, timedelta

import discord
from discord import app_commands
from discord.ext import commands, tasks

TOKEN = os.environ["DISCORD_TOKEN"]
GUILD_ID = int(os.environ["DISCORD_GUILD_ID"])
SERVICE = os.environ.get("PZ_SERVICE", "pz-fex.service")
HELPER = "/usr/local/sbin/pz-bot-query"
WORLD_HELPER = "/usr/local/sbin/pz-bot-world"
GUILD = discord.Object(id=GUILD_ID)
PZ_CHAT_CHANNEL = "pz-chat"

intents = discord.Intents.default()
bot = commands.Bot(command_prefix=commands.when_mentioned, intents=intents)

def duration(seconds):
    if seconds is None:
        return "—"

    seconds = max(0, int(seconds))
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes = rem // 60

    parts = []
    if days:
        parts.append(f"{days}d")
    if hours or days:
        parts.append(f"{hours}h")
    parts.append(f"{minutes}m")
    return " ".join(parts)

async def run_cmd(*args, timeout=8):
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise

    return proc.returncode, stdout.decode(errors="replace").strip(), stderr.decode(errors="replace").strip()

async def systemd_state():
    rc, out, err = await run_cmd(
        "systemctl", "show", SERVICE,
        "-p", "ActiveState",
        "-p", "SubState",
        "-p", "ActiveEnterTimestampMonotonic",
        "--no-pager",
    )

    data = {}
    for line in out.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            data[key] = value

    return {
        "active": data.get("ActiveState", "unknown"),
        "sub": data.get("SubState", "unknown"),
        "entered_us": int(data.get("ActiveEnterTimestampMonotonic", "0") or 0),
    }

async def query_pz():
    rc, out, err = await run_cmd("sudo", "-n", HELPER, timeout=15)
    if rc != 0 or not out:
        return {"rcon_ok": False, "count": 0, "max_players": 32, "players": []}

    try:
        return json.loads(out.splitlines()[-1])
    except Exception:
        return {"rcon_ok": False, "count": 0, "max_players": 32, "players": []}


async def query_world():
    rc, out, err = await run_cmd(
        "sudo", "-n", WORLD_HELPER,
        timeout=8,
    )

    if rc != 0 or not out:
        return None

    raw = {}

    for line in out.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            raw[key.strip()] = value.strip()

    try:
        return {
            "year": int(float(raw["year"])),
            "month": int(float(raw["month"])),
            "day": int(float(raw["day"])),
            "hour": int(float(raw["hour"])),
            "minute": int(float(raw["minute"])),
            "world_age_hours": float(raw["world_age_hours"]),
            "minutes_per_day": float(raw["minutes_per_day"]),
            "players": int(float(raw["players"])),
            "paused": raw["paused"].lower() == "true",
            "temperature_c": float(raw["temperature_c"]),
            "precipitation_intensity": float(
                raw["precipitation_intensity"]
            ),
            "precipitation_type": raw["precipitation_type"],
            "thunder": raw["thunder"].lower() == "true",
            "updated_epoch": int(float(raw["updated_epoch"])),
            "reason": raw.get("reason", "unknown"),
        }
    except (KeyError, ValueError):
        return None


def estimated_world_time(world):
    current = datetime(
        world["year"],
        world["month"],
        world["day"],
        world["hour"],
        world["minute"],
    )

    if world["paused"]:
        return current

    elapsed_real_seconds = max(
        0.0,
        time.time() - world["updated_epoch"],
    )

    minutes_per_day = world["minutes_per_day"]

    if minutes_per_day <= 0:
        return current

    game_minutes_per_real_second = (
        1440.0 / (minutes_per_day * 60.0)
    )

    elapsed_game_minutes = (
        elapsed_real_seconds *
        game_minutes_per_real_second
    )

    return current + timedelta(
        minutes=elapsed_game_minutes
    )


def weather_text(world):
    lines = [
        f'🌡️ **{world["temperature_c"]:.1f} °C**'
    ]

    precip = max(
        0.0,
        min(1.0, world["precipitation_intensity"]),
    )

    precip_percent = round(precip * 100)
    kind = world["precipitation_type"].lower()

    if kind == "rain" and precip > 0.01:
        lines.append(f"🌧️ Rain — **{precip_percent}%**")
    elif kind == "snow" and precip > 0.01:
        lines.append(f"🌨️ Snow — **{precip_percent}%**")
    else:
        lines.append("☁️ No precipitation")

    if world["thunder"]:
        lines.append("⛈️ Thunderstorm")

    return "\n".join(lines)


def service_uptime(state):
    if state["active"] != "active" or not state["entered_us"]:
        return None

    with open("/proc/uptime", "r", encoding="utf-8") as f:
        boot_seconds = float(f.read().split()[0])

    entered_seconds = state["entered_us"] / 1_000_000
    return max(0, int(boot_seconds - entered_seconds))

async def snapshot():
    state = await systemd_state()

    if state["active"] == "activating" or state["sub"] == "auto-restart":
        return {
            "label": "Restarting",
            "emoji": "🟠",
            "uptime": None,
            "count": 0,
            "max_players": 32,
            "players": [],
        }

    if state["active"] != "active":
        return {
            "label": "Offline",
            "emoji": "🔴",
            "uptime": None,
            "count": 0,
            "max_players": 32,
            "players": [],
        }

    pz = await query_pz()
    up = service_uptime(state)

    if not pz.get("rcon_ok"):
        return {
            "label": "Starting",
            "emoji": "🟡",
            "uptime": None,
            "count": 0,
            "max_players": pz.get("max_players", 32),
            "players": [],
        }

    return {
        "label": "Online",
        "emoji": "🟢",
        "uptime": up,
        "count": pz.get("count", 0),
        "max_players": pz.get("max_players", 32),
        "players": pz.get("players", []),
    }

def status_embed(snap, include_commands=False):
    embed = discord.Embed(
        title="RBX — Project Zomboid",
        color={
            "Online": 0x57F287,
            "Starting": 0xFEE75C,
            "Restarting": 0xF0A65A,
            "Offline": 0xED4245,
        }.get(snap["label"], 0x5865F2),
    )

    embed.add_field(name="Status", value=f'{snap["emoji"]} {snap["label"]}', inline=True)
    embed.add_field(
        name="Uptime",
        value=duration(snap["uptime"]) if snap["label"] == "Online" else "—",
        inline=True,
    )
    embed.add_field(
        name="Players",
        value=f'{snap["count"]}/{snap["max_players"]}',
        inline=True,
    )

    if include_commands:
        embed.add_field(
            name="Commands",
            value=(
                "`/status` — server status, uptime and player count\n"
                "`/players` — detailed list of connected players\n"
            "`/time` — in-game time and weather"
            ),
            inline=False,
        )

    return embed

@bot.tree.command(name="rbx", description="RBX server overview and commands", guild=GUILD)
async def rbx(interaction: discord.Interaction):
    await interaction.response.defer(thinking=True)
    snap = await snapshot()
    await interaction.followup.send(embed=status_embed(snap, include_commands=True))

@bot.tree.command(name="status", description="Show Project Zomboid server status", guild=GUILD)
async def status(interaction: discord.Interaction):
    await interaction.response.defer(thinking=True)
    snap = await snapshot()
    await interaction.followup.send(embed=status_embed(snap))

@bot.tree.command(name="players", description="Show players currently connected", guild=GUILD)
async def players(interaction: discord.Interaction):
    await interaction.response.defer(thinking=True)
    snap = await snapshot()

    if snap["label"] != "Online":
        await interaction.followup.send(
            f'{snap["emoji"]} Server is **{snap["label"].lower()}**.',
            ephemeral=True,
        )
        return

    embed = discord.Embed(
        title=f'Players — {snap["count"]}/{snap["max_players"]}',
        color=0x57F287,
    )

    if not snap["players"]:
        embed.description = "No players connected."
    else:
        lines = []
        for player in snap["players"]:
            name = discord.utils.escape_markdown(player["name"])
            connected = player.get("connected_epoch")
            online = duration(player.get("online_seconds"))

            if connected:
                lines.append(
                    f'**{name}**\n'
                    f'Connected: <t:{connected}:f>\n'
                    f'Online: `{online}`'
                )
            else:
                lines.append(
                    f'**{name}**\n'
                    f'Connected: unknown\n'
                    f'Online: `—`'
                )

        embed.description = "\n\n".join(lines)

    await interaction.followup.send(embed=embed)


@bot.tree.command(
    name="time",
    description="Show in-game time and weather",
    guild=GUILD,
)
async def world_time(interaction: discord.Interaction):
    await interaction.response.defer(thinking=True)

    snap = await snapshot()

    if snap["label"] != "Online":
        await interaction.followup.send(
            f'{snap["emoji"]} Server is **{snap["label"].lower()}**.',
            ephemeral=True,
        )
        return

    world = await query_world()

    if not world:
        await interaction.followup.send(
            "⚠️ World time data is currently unavailable.",
            ephemeral=True,
        )
        return

    current = estimated_world_time(world)

    embed = discord.Embed(
        title="RBX — World",
        color=0x5865F2,
    )

    embed.add_field(
        name="Time",
        value=(
            f'🕒 **{current:%H:%M}**\n'
            f'📅 {current.day} {current:%B} {current.year}'
        ),
        inline=False,
    )

    embed.add_field(
        name="Weather",
        value=weather_text(world),
        inline=False,
    )

    if world["paused"]:
        embed.set_footer(
            text="World paused • time is not advancing"
        )
    else:
        age = max(
            0,
            int(time.time() - world["updated_epoch"])
        )

        embed.set_footer(
            text=f"Estimated from server snapshot • {age}s old"
        )

    await interaction.followup.send(embed=embed)



watched_players = None


@tasks.loop(seconds=5)
async def player_watch_loop():
    global watched_players

    try:
        snap = await snapshot()

        # During restart/offline/starting:
        # forget the old baseline so planned restarts do not announce
        # everybody as "left".
        if snap["label"] != "Online":
            watched_players = None
            return

        current = {
            player["name"]
            for player in snap["players"]
        }

        # First healthy sample becomes baseline.
        if watched_players is None:
            watched_players = current
            return

        joined = current - watched_players
        left = watched_players - current

        watched_players = current

        if not joined and not left:
            return

        guild = bot.get_guild(GUILD_ID)

        if guild is None:
            print("RBX player watcher: guild unavailable", flush=True)
            return

        channel = discord.utils.get(
            guild.text_channels,
            name=PZ_CHAT_CHANNEL,
        )

        if channel is None:
            print(
                f"RBX player watcher: #{PZ_CHAT_CHANNEL} unavailable",
                flush=True,
            )
            return

        for name in sorted(joined):
            safe = discord.utils.escape_markdown(name)
            embed = discord.Embed(
                description=f"🟢 **{safe}** joined the server.",
                color=0x57F287,
            )
            await channel.send(embed=embed)

        for name in sorted(left):
            safe = discord.utils.escape_markdown(name)
            embed = discord.Embed(
                description=f"🔴 **{safe}** left the server.",
                color=0xED4245,
            )
            await channel.send(embed=embed)

    except Exception as exc:
        print(
            f"RBX player watcher error: {exc!r}",
            flush=True,
        )


@player_watch_loop.before_loop
async def before_player_watch_loop():
    await bot.wait_until_ready()


@tasks.loop(seconds=60)
async def presence_loop():
    try:
        snap = await snapshot()

        if snap["label"] == "Online":
            text = f'{snap["count"]}/{snap["max_players"]} | uptime {duration(snap["uptime"])}'
        elif snap["label"] == "Starting":
            text = "server starting..."
        elif snap["label"] == "Restarting":
            text = "server restarting..."
        else:
            text = "server offline"

        await bot.change_presence(
            status=discord.Status.online,
            activity=discord.Game(name=text),
        )
    except Exception:
        pass

@presence_loop.before_loop
async def before_presence_loop():
    await bot.wait_until_ready()

@bot.event
async def on_ready():
    if not presence_loop.is_running():
        presence_loop.start()

    if not player_watch_loop.is_running():
        player_watch_loop.start()
    print(f"Logged in as {bot.user} ({bot.user.id})", flush=True)

async def setup_hook():
    synced = await bot.tree.sync(guild=GUILD)
    print(f"Synced {len(synced)} guild commands", flush=True)

bot.setup_hook = setup_hook
bot.run(TOKEN, log_handler=None)
