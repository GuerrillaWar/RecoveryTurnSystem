# Recovery Turn System

This is a new take on the turn based system of XCOM, making it work much like the Recovery System of Tactics Ogre: Let Us Cling Together.
Much like XCOM it gives you only a few actions per turn per unit, but you also only ever get to command one unit at a time.

Instead of taking simple full team turns, each unit has a recovery time. That recovery ticks down so whichever Unit has the lowest recovery time goes next.
That Unit takes their moves, or passes, and then their recovery times gets set back based on how many Action Points they used.
Roughly the default recovery times are:

- 2 or more actions points remaining: 5 recovery time
- 1 action point remaining: 10-20 recovery time (depending on the mobility of the unit)
- 0 action points remaining: 20-40 recovery time (again, depending on the mobility of the unit)

This gives you an option NOT to take a move with a unit if you'd like to sync up the squads actions in some way.

The current action order is shown on the bottom left of screen, with the order bottom first, top last. Only visible units
will be shown on the display. Mouse over the icons and the camera will pan to the relevant Unit, just like the targeting icons.

Finally, there still needs to be a standard counting of 'turns' so that the Ability Cooldowns and Mission Timers have something to latch on to.
The 'turn' timer is represented as a Gold Star, so whenever that comes around the turn 'ends', ticking down cooldowns and timers and things.


# Why?

To experiment. XCOM's gameplay focusses a little too much on taking turns to Alpha Strike the opponent with your whole squad. This is an attempt to
shuffle that up a bit, give the enemy more chances to shoot, and hopefully a more fluid firefight.


# Problems?

This mod should be save game friendly, although don't load a save game thats in Tactical if it didn't start with this mod. No elements of the strategy game are
changed, so it should play nice with a lot of other mods.

# Class Overrides
The following game classes are overridden:

X2TacticalGameRuleset
XGPlayer
XGAIPlayer

This mod will conflict with any mods that also use these overrides (which for the moment includes WaveCOM and Guerrilla War)