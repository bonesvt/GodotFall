import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
G="death pain grunts.wav"
e={}
# Eco foley
for i in range(5):
    e[f"step_grass_{i+1}"]={"layers":[{"src":f"footstep_grass_00{i}.ogg","fadeout":0.08}],"norm":-3}
    e[f"step_concrete_{i+1}"]={"layers":[{"src":f"footstep_concrete_00{i}.ogg","fadeout":0.04}],"norm":-3}
    e[f"step_wood_{i+1}"]={"layers":[{"src":f"footstep_wood_00{i}.ogg","fadeout":0.05}],"norm":-3}
for i,n in enumerate(["01","02","03","04","05"]):
    e[f"step_gravel_{i+1}"]={"layers":[{"src":f"Corsica_S-Walking_on_snow_covered_gravel_{n}.flac","dur":0.45,"fadeout":0.15}],"norm":-3}
for i,n in enumerate(["step_metal.ogg","step_metal (2).ogg","step_metal (3).ogg","step_metal (4).ogg"]):
    e[f"step_metal_{i+1}"]={"layers":[{"src":n,"fadeout":0.05}],"norm":-3}
e["land"]={"layers":[{"src":"boots-leather-jump-01.wav","fadeout":0.1}]}
e["land_heavy"]={"layers":[{"src":"boots-leather-jump-02.wav","fadeout":0.1},{"src":"footstep_grass_002.ogg","gain":-4}]}
for i in range(3): e[f"cloth_{i+1}"]={"layers":[{"src":f"step_cloth{i+1}.ogg","fadeout":0.05}],"norm":-6}
e["knife_sheathe"]={"layers":[{"src":"knife-sheathe-01.wav","fadeout":0.1}]}
e["shell_casing"]={"layers":[{"src":"singlebullet1.wav","hp":800,"fadeout":0.08}],"norm":-6}
e["mag_drop"]={"layers":[{"src":"bfh1_metal_falling_03.ogg","fadeout":0.1}],"norm":-4}
e["heartbeat"]={"layers":[{"src":"heartbeat.mp3_.flac","dur":1.1,"fadeout":0.2}]}
e["flare"]={"layers":[{"src":"flare-ignition/ignition.flac","fadeout":0.3}]}
# Titans
for i,p in enumerate([0.92,1.0,1.08]):
    e[f"titan_step_{i+1}"]={"layers":[{"src":"mech-stomp-step-sound/stomp.flac","pitch":p,"fadeout":0.2},{"src":"dull_metal_collision_0%d_44k"%(i+1),"gain":-10,"pitch":0.7,"lp":1500,"dur":0.3}]}
e["titan_servo_1"]={"layers":[{"src":"ROBOTIC_Transformation_Insect_01_Servos_Clicks_Digital_stereo.wav","fadeout":0.2,"lp":9000}],"norm":-4}
e["titan_servo_2"]={"layers":[{"src":"ROBOTIC_Transformation_Insect_02_Servos_Clicks_Digital_stereo.wav","fadeout":0.2,"lp":9000}],"norm":-4}
e["titan_servo_3"]={"layers":[{"src":"mechanical-sounds/mechanical1.wav","pitch":0.8,"fadeout":0.2}],"norm":-4}
e["titan_servo_4"]={"layers":[{"src":"mechanical-sounds/mechanical2.wav","pitch":0.8,"fadeout":0.15}],"norm":-4}
e["titan_hiss"]={"layers":[{"src":"steam hisses - Marker #1.wav","fadeout":0.6}],"norm":-4}
e["titan_hiss_short"]={"layers":[{"src":"steam hisses - Marker #2.wav","dur":0.8,"fadeout":0.4}],"norm":-4}
e["titan_embark"]={"layers":[{"src":"compressed_gas_leak_0.ogg","dur":1.2,"fadeout":0.5,"gain":-4},{"src":"metal_close_01.ogg","delay":0.5},{"src":"mechanical-sounds/clank1.wav","delay":0.9,"gain":-3}]}
e["titan_boot"]={"layers":[{"src":"electricity-game-sound-pack/powerup.wav","fadeout":0.3},{"src":"switch on.wav","gain":-4}]}
e["titan_powerdown"]={"layers":[{"src":"electricity-game-sound-pack/powerdown.wav","fadeout":0.4}]}
e["titan_core_charge"]={"layers":[{"src":"chargestart.wav","dur":2.5,"fadeout":0.4}]}
e["titan_core_drain"]={"layers":[{"src":"qubodup-PowerDrain.ogg","fadeout":0.5}]}
e["splitter_beam_loop"]={"layers":[{"src":"movingshield_sound.ogg"}],"loop":True,"xfade":0.5,"norm":-3}
e["titan_rocket"]={"layers":[{"src":"launch/launch.wav","dur":2.0,"fadeout":0.8}]}
e["titan_metal_creak"]={"layers":[{"src":"metal_grit_02_44k_32bit_stereo.wav","fadeout":0.4}],"norm":-4}
e["titan_clang"]={"layers":[{"src":"dull_metal_collision_10_44k_32bit_stereo.wav","fadeout":0.4}]}
e["titan_doom_laser"]={"layers":[{"src":"doomsday_laser_cannon_short.wav","fadeout":0.6}]}
# Explosions
e["explosion_big"]={"layers":[{"src":"explosions-4/explosion1_0.ogg","dur":3.0,"fadeout":1.2}]}
e["explosion_small"]={"layers":[{"src":"explosions-4/explosion3.ogg","fadeout":0.5}]}
e["explosion_far"]={"layers":[{"src":"explosion_somewhere_far.mp3","fadeout":0.8}]}
e["explosion_muffled"]={"layers":[{"src":"Muffled Distant Explosion.wav","fadeout":0.8}]}
e["explosion_metal"]={"layers":[{"src":"mechanical_explosion.wav","fadeout":0.4}]}
e["debris_rock"]={"layers":[{"src":"bfh1_rock_breaking_01.ogg","fadeout":0.3}]}
e["debris_metal"]={"layers":[{"src":"bfh1_metal_falling_01.ogg","fadeout":0.3}]}
e["glass_break"]={"layers":[{"src":"bfh1_glass_breaking_01.ogg","fadeout":0.3}]}
# Grunts (militia voices)
cuts=[(0.5,1.45),(3.97,2.2),(6.93,0.5),(8.35,0.82),(14.44,1.72),(20.41,1.76),(23.87,1.84),(27.59,0.94),(29.84,0.52),(31.53,1.03),(35.97,1.4)]
for i,(s,d) in enumerate(cuts):
    e[f"grunt_pain_{i+1}"]={"layers":[{"src":G,"start":s,"dur":d,"fadeout":0.15}],"norm":-2}
for i,f in enumerate(["1yell1","1yell5","2yell3","3yell2","yell3","2yell7","3yell8","yell9"]):
    e[f"grunt_yell_{i+1}"]={"layers":[{"src":f"yelling sounds/{f}.wav","fadeout":0.12}],"norm":-2}
for i,f in enumerate(["3grunt1","3grunt2","3grunt3","3grunt4","3grunt5","3grunt6"]):
    e[f"grunt_effort_{i+1}"]={"layers":[{"src":f"yelling sounds/{f}.wav","fadeout":0.1}],"norm":-3}
for i,f in enumerate(["slightscream-01","slightscream-04","slightscream-07","slightscream-10","slightscream-15"]):
    e[f"grunt_hurt_{i+1}"]={"layers":[{"src":f"{f}.flac","fadeout":0.08}],"norm":-3}
e["grunt_hey"]={"layers":[{"src":"hey_aggressive_mujtaba.wav","fadeout":0.1}]}
e["grunt_kill_you"]={"layers":[{"src":"i_will_kill_you_aggressive_mujtaba.wav","fadeout":0.1}]}
# Radio
e["radio_squelch_on"]={"layers":[{"src":"walkie static.wav","hp":300,"lp":5000,"fadeout":0.04}],"norm":-4}
e["radio_squelch_off"]={"layers":[{"src":"walkie static.wav","pitch":1.2,"hp":300,"lp":5000,"fadeout":0.06},{"src":"Clic03.mp3.flac","gain":-8,"delay":0.16}],"norm":-4}
e["radio_static_burst"]={"layers":[{"src":"static/ScatterNoise1.mp3","start":2.0,"dur":0.6,"hp":400,"lp":4500,"fadeout":0.25}],"norm":-6}
e["radio_dead"]={"layers":[{"src":"radio_death_0.ogg","fadeout":0.5}],"norm":-3}
# World / hub
e["door_iron"]={"layers":[{"src":"iron_door_0.ogg","fadeout":0.2}]}
e["door_stone"]={"layers":[{"src":"stone_door.ogg","start":0.1,"fadeout":0.3}]}
e["door_metal_open"]={"layers":[{"src":"metal_open_01.ogg","fadeout":0.2}]}
e["door_metal_close"]={"layers":[{"src":"metal_close_01.ogg","fadeout":0.2}]}
e["cache_unlock"]={"layers":[{"src":"/lock_open_01.ogg","fadeout":0.15}]}
e["cache_open"]={"layers":[{"src":"/lock_open_01.ogg"},{"src":"metal_open_01.ogg","delay":0.35}]}
e["pickup_part"]={"layers":[{"src":"workshop - clink.wav","fadeout":0.2},{"src":"step_lth1.ogg","gain":-6}]}
e["workbench_drill"]={"layers":[{"src":"workshop - drill short 1.wav","fadeout":0.2}]}
e["workbench_ratchet"]={"layers":[{"src":"workshop - ratchet1.wav","dur":1.6,"fadeout":0.3}]}
e["workbench_hammer"]={"layers":[{"src":"workshop - metal hammering.wav","fadeout":0.3}]}
e["workbench_tools"]={"layers":[{"src":"workshop - tool rummaging.wav","dur":2.0,"fadeout":0.4}]}
e["workbench_squeeze"]={"layers":[{"src":"roboticsqueeze.flac","fadeout":0.1,"lp":10000}]}
e["tree_creak"]={"layers":[{"src":"tree_creak_0.ogg","fadeout":0.8}],"norm":-4}
# UI
e["ui_click"]={"layers":[{"src":"Clic03.mp3.flac","fadeout":0.05}],"norm":-6}
e["ui_hover"]={"layers":[{"src":"menu1.wav","fadeout":0.05}],"norm":-10}
e["ui_confirm"]={"layers":[{"src":"dingCling-positive.ogg","fadeout":0.08}],"norm":-6}
e["ui_error"]={"layers":[{"src":"dingCling-negative.ogg","fadeout":0.08}],"norm":-6}
e["ui_switch"]={"layers":[{"src":"switch on.wav","fadeout":0.1}],"norm":-6}
e["ui_terminal"]={"layers":[{"src":"/terminal_04.ogg","fadeout":0.05}],"norm":-8}
json.dump(e,open(os.path.join(HERE,'extras.json'),'w'),indent=1)
# Ambience loops (stereo)
a={}
A=lambda src,start,dur,rms=-24,xf=2.0,**k: {"stereo":True,"loop":True,"xfade":xf,"rms":rms,"q":0,"layers":[dict(src=src,start=start,dur=dur+xf,fadein=0.01,fadeout=0.001,**k)]}
a["forest_day"]=A("amb_outdoor1_loop.ogg",0,22)
a["forest_morning"]=A("amb_morning_0.ogg",5,22)
a["forest_birds"]=A("birds-isaiah658_0.ogg",0,22,rms=-28)
a["forest_wind"]=A("wind1/wind2.wav",5,22,rms=-27)
a["wind_soft"]=A("wind background noise 2.wav",2,22,rms=-30)
a["forest_night"]=A("crickets_1.mp3",0,9,rms=-28,xf=1.0)
a["swamp_creek"]=A("swamp-environment-audio/swamp.ogg",20,22)
a["rain"]=A("rain-loopable/x/1.ogg",0,24,rms=-24)
a["temple_interior"]=A("dungeon_ambient_1_0.ogg",10,30,rms=-28,xf=3.0)
a["temple_drips"]=A("atmosbasement.mp3_.flac",0,17,rms=-30)
a["temple_eerie"]=A("atmoseerie03.mp3.flac",0,17,rms=-30)
a["campfire"]=A("fire-1_0.ogg",0,2.8,rms=-26,xf=0.6)
a["machine_hum"]=A("loop_generator_1.mp3",0,4.4,rms=-28,xf=0.8)
a["radio_static_loop"]=A("radio_noise_loop.wav",5,12,rms=-30,xf=1.0)
json.dump(a,open(os.path.join(HERE,'ambience.json'),'w'),indent=1)
print(len(e),len(a))
