extends SceneTree
## Writes a few lines of each hub person's babble to WAV files, to hear the
## voices without playing:
##   godot --headless --path . -s res://tools/npc/babble_preview.gd -- [out_dir]

const Babble := preload("res://scripts/hub/babble.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://babble"
	DirAccess.make_dir_recursive_absolute(out)
	for who in ["mom", "ophelia", "biggie"]:
		var f := FileAccess.open("res://dialogue/npc/%s.txt" % who, FileAccess.READ)
		var bank := NpcTalk.parse(f.get_as_text())
		# their intro, as a back-and-forth with Eco, half a second between lines
		var data := PackedByteArray()
		for line in bank["intro"]:
			var b := Babble.make(line[0], line[1])
			data.append_array(b["stream"].data)
			data.resize(data.size() + Babble.RATE)   # 0.5 s of silence (16-bit)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = Babble.RATE
		wav.data = data
		wav.save_to_wav(out.path_join(who + "_intro.wav"))
		print("wrote ", who)
	quit()
