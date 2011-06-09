--------------------------------------------------------------
-- Card class
--------------------------------------------------------------

local card_mt = {
	__eq = function(a, b) return a.speed == b.speed and a.lift == b.lift end,
	__add = function(a, b) return Card(a.speed + b.speed, a.lift + b.lift) end,
	__tostring = function(e) return e.speed.."//"..e.lift.. ' "'.. e.name.. '"' end
	}

function Card(speed, lift)
	local zeroCards = {"10,000 spoons: All you needed was a knife.", "Anchor: Ain't nothin' gonna break-a my stride.", "True Love: Takes up way too much space.",
		"A lengthy phonecall from your friend back in college: It's about time I took this.", "Alcoholism: Beats the alternative.", "Family Guy Season 4: This goes downhill fast."}

	local speedCards = {"The 77 Toaster Engine: Demands 154 bread.", "Trained monkey with fez: And a bell.", "African American dentist: Open wide and say deeeeeeeeamn!",
		"Prostitute on a Segue: Now she's got the right idea.", "Giant spider with blood-covered shovels for legs: JESUS GODDAMMING CHRIST.", "Tandem bicycle: We'll look sweet upon the seat.",
		"Coffee Addicted Eskimo: The best part of waking up.", "RC car: Eh.", "5 AM Jogger with the Huge Jugs: Maybe it's time for my morning constitutional as well.",
		"1979 GTO: Comes with hot women with giant hair.", "Pavel's Car: Listen to that engine whine.", "Mine cart: Mayhem.", "Tokyo Drift gang: The lady in white pleather just swung the go-flag.",
		"Rush Limbaugh sees Michael J Fox 5: Cue the Sabre Dance.", "Jeff Goldblum on a pair of colossal stilts: Yes yes.  Yes, yeeees.  Yes!  Stilts.", "Comically-oversized magnet: It pulls the race back to you!"}

	local liftCards = {"Music box: Puts all hammer bros. in play to sleep.", "-2 ton weight: We all know that all objects fall up at the same rate, regardless of mass.",
		"My beautiful, my beautiful ballooooooon: Up and away.", "Cameron Winters: If only I could have remained...", "Spanish flea by the Tijuana Brass only in reverse: It is as if God Himself is speed dating.",
		"Just another fucking balloon: Ugh.", "Boxers, right out of the freezer: Like an ice cold beer for your testicles.", "Snowglobe: Xanaduuuuu...", "Air screw: Da Vinci was so far behind him time.",
		"Balloon: one, blue.", "New York style hotdog kiosk: Mustard, relish?  Yo!  Fuggeddabouddit.", "Hot-Air Balloon: Around the world in 80 days.",
		"Roswellian Airfoil: This technology is strangely familiar (anus-scratching noise).", "One forgotten vector: Such a magnificent magnitude gone to waste.",
		"Matthew Lesko's Inquisition Coat: Tell bill collectors to go shove it.", "Buouyant Carrot: Vitamin Up."}

	local this = {}
	this.speed = speed
	this.lift = lift
	if lift == 0 and speed == 0 then
		this.name = zeroCards[math.random(#zeroCards)]
	elseif lift >= speed then
		this.name = liftCards[math.random(#liftCards)]
	elseif lift < speed then
		this.name = speedCards[math.random(#speedCards)]
	end
	setmetatable(this, card_mt)
	return this
end -- Card

--------------------------------------------------------------
-- Player class
--------------------------------------------------------------

local player_mt = {
	__tostring = function(e) return e.name.." - Points "..e.points.." -"..cardsToString(e) end}

function Player(name, next)
	local this = {}
	this.name = name
	this.next = next
	this.points = 0
	this.cards = {}
	setmetatable(this, player_mt)
	return this
end -- Player


function cardsToString(player)
	local cards = ""
	for _,card in ipairs(player.cards) do
		cards = cards.. " ".. tostring(card)
	end
	return cards
end

--------------------------------------------------------------
-- NSRX
--------------------------------------------------------------

local NSRX = {channel="#NSRX", inGame = false, players = {}, colours = {black = "01", blue = "02", green = "03", red = "05", grey = "14"}}
NSRX._index = NSRX
local rand = math.random

function NSRX:parseCommand(nick, msg)
	if msg:find("^!add") and self.players[nick] == nil and not self.inGame then
		self.players[nick] = Player(nick, self.currentPlayer)
		self.currentPlayer = self.players[nick]
		privmsg (self.channel, self.colours.blue..self.currentPlayer.name.." was added.")
	elseif msg:find("^!start") then
		for _,player in pairs(self.players) do
			if player.next == nil then
				player.next = self.currentPlayer
			end
		end
		self.inGame = true
		privmsg (self.channel, self:newTurn())
	elseif msg:find("^!play") and nick == self.currentPlayer.name then
		self.dealtTo = self.players[msg:match('^!play (.-)%s*$')]
		if self.dealtTo then
			if #self.dealtTo.cards < 3 then
				self:dealCard()
				privmsg (self.channel, self:newTurn())
			else
				privmsg (self.channel, self.colours.red.."You already have ".. #self.dealtTo.cards.. " cards.")
				privmsg (self.channel, self.colours.green.."Choose a card to remove:"..cardsToString(self.dealtTo))
			end
		else
			privmsg (self.channel, self.colours.blue..msg:match('^!play (.-)%s*$').." does not exist.")
		end
	elseif msg:find("^!card") and nick == self.currentPlayer.name then
		self.currentCard = Card(rand(6), rand(6))
		privmsg (self.channel, tostring(self.currentCard))
	elseif self.players[msg:match('^!(.-)%s*$')] then
		privmsg (self.channel, self.colours.green..tostring(self.players[msg:match('^!(.-)%s*$')]))
	elseif self.dealtTo ~= nil and nick == self.dealtTo.name then
		local speed, lift = msg:match("(%d)//(%d)")
		local toRemove = Card(tonumber(speed), tonumber(lift))
		for i,card in ipairs(self.dealtTo.cards) do
			if card == toRemove then
				table.remove(self.dealtTo.cards, i)
				privmsg(self.channel, self.colours.red.."Removed ".. tostring(card) .. " from ".. self.dealtTo.name .. ".")
				break
			end
		end
		if #self.dealtTo.cards >= 3 then
			privmsg (self.channel, self.colours.green.."You don't have that card.")
		end
		self:dealCard()
		privmsg (self.channel, self:newTurn())
	elseif msg:find("^!end") and self.inGame then
		self.currentPlayer = nil
		self.inGame = false
		self.players = {}
		privmsg (self.channel, self.colours.blue.."Game ended.")
	end
end

function NSRX:dealCard()
	table.insert(self.dealtTo.cards, self.currentCard)
	privmsg (self.channel, "Played ".. tostring(self.currentCard).." to ".. self.dealtTo.name..".")
	local total = Card(0,0)
	local message = ""
	for _, card in ipairs(self.dealtTo.cards) do
		total = total + card
	end
	if total.lift > 7 or total.speed > 7 then
		self.dealtTo.cards = {}
		message = self.dealtTo.name .." now has no cards."
	elseif total.lift == 7 and total.speed == 7 then
		self.dealtTo.points = self.dealtTo.points + 4
		message = self.dealtTo.name .." gets four points for a total of ".. self.dealtTo.points .."."
	elseif total.lift == 7 or total.speed == 7 then
		if total.lift == 0 or total.speed == 0 then
			self.dealtTo.points = self.dealtTo.points + 2
			message = self.dealtTo.name .." gets two points for a total of ".. self.dealtTo.points .."."
		else
			self.dealtTo.points = self.dealtTo.points + 1
			message = self.dealtTo.name .." gets one point for a total of ".. self.dealtTo.points .."."
		end
	end
	privmsg (self.channel, self.colours.green..self.dealtTo.name.."'s hand total is "..total.speed.."//"..total.lift..". ".. message)

	if self.dealtTo.points >= 7 then
		privmsg (self.channel, self.colours.blue.."Game over! "..self.dealtTo.name.. "has won!")
		self.currentPlayer = nil
		self.inGame = false
		self.players = {}
	end
end


function NSRX:newTurn()
	if self.inGame then
		self.dealtTo = nil
		self.currentCard = Card(rand(6) - 1, rand(6) - 1)
		self.currentPlayer = self.currentPlayer.next
		return self.colours.red.."Current player: ".. self.currentPlayer.name.. ": Current card: "..tostring(self.currentCard).."."
	end
end


return NSRX

--~ <blue_tetris> Blue for game functions, red for in-game turns, green for cards and information?
