require("utilities.table") -- extends the base table metatable
require("utilities.string") -- extends the base string metatable
local client = require("client")
local argparse = require("utilities.argparse")
local GameManager = require("gameManager")

local parser = argparse():description("Runs the Cadre Lua client to connect to a game server and play games with its AI.")
parser:argument("game"):description("the name of the game you want to play on the server")
parser:option("-s", "--server"):description("the host server you want to connect to e.g. localhost:3000"):default("localhost")
parser:option("-p", "--port"):description("port to connect to host server through"):default("3000")
parser:option("-n", "--name"):description("the name you want to use as your AI's player name")
parser:option("-r", "--session"):description("the requested game session you want to play in on the server"):default("*")
parser:flag("--printIO"):description("(debugging) print IO through the TCP socket to the terminal")

local args = parser:parse()

local splitServer = args.server:split(":")
args.server = splitServer[1]
args.port = tonumber(splitServer[2] or args.port)

local game = require("games." .. args.game .. ".game")()
local ai = require("games." .. args.game .. ".ai")(game)
local gameManager = GameManager(game)

client:setup(game, ai, gameManager, args.server, args.port, args)

client:send("play", {
    gameName = args.game,
    requestedSession = args.session,
    clientType = "Lua",
    playerName = args.playerName or ai:getName() or "Lua Player",
})

local lobbyData = client:waitForEvent("lobbied")

print("In Lobby for game '" .. lobbyData.gameName .. "' in session '" .. lobbyData.gameSession .. "'")

gameManager:setConstants(lobbyData.constants)

local startData = client:waitForEvent("start")

print("Game starting")

ai:setPlayer(game:getGameObject(startData.playerID))
ai:start()
ai:gameUpdated()

while true do -- the client will decide when to os.exit
    local data = client:waitForEvent("order")

    local returned = ai:_doOrder(data.order, data.args)

    client:send("finished", {
        finished = data.order,
        returned = returned,
    })
end
