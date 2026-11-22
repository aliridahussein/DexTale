class_name ResonanceRitual
extends RefCounted
## The Bell's Resonance (V2): the retuning the player performs for The Chorus.
##
## Rowan leads the Gathering Song on the bell, one note at a time, by its
## shape: each next note is higher (UP) or lower (DOWN) than the one before,
## exactly as the thirteen marks rise and fall in the ledger's margin. The
## thirteenth note, the circled one ("the note that gives back"), is sung
## with SING. There is no timing. A wrong note sours the bell and the current
## phrase starts over; nothing else is lost. Pure logic, so tests can drive it.

enum Note { UP, DOWN, SING }
enum Result { NEXT, PHRASE_DONE, WRONG, DONE, IGNORED }

## Pitch steps of the song (0 = lowest). Must match the ledger marks
## (tools/art/ui_art.py SONG_NOTES) and the music (generate_audio.py SONG_STEPS).
const SONG: Array[int] = [2, 3, 4, 3, 5, 4, 2, 1, 2, 4, 3, 1, 0]
## Index of the first note of each phrase: the song breathes after the eighth.
const PHRASES: Array[int] = [0, 8]
## Semitones above D4 for each pitch step (D4 F4 G4 A4 C5 D5).
const SEMITONES: Array[int] = [0, 3, 5, 7, 10, 12]

## Notes sounded so far. The bell gives the first one.
var sung := 1
var mistakes := 0
## note index -> how often it was missed (a missed note shows its direction)
var miss_counts: Dictionary = {}
var done := false


static func needed_for(index: int) -> Note:
	if index == SONG.size() - 1:
		return Note.SING
	return Note.UP if SONG[index] > SONG[index - 1] else Note.DOWN


## The full correct input sequence (handy for tests and the tour).
static func solution() -> Array[Note]:
	var out: Array[Note] = []
	for i in range(1, SONG.size()):
		out.append(needed_for(i))
	return out


static func pitch_scale(index: int) -> float:
	return pow(2.0, SEMITONES[SONG[index]] / 12.0)


func next_needed() -> Note:
	return needed_for(sung)


func phrase_start() -> int:
	var start := 1
	for p in PHRASES:
		if p > 0 and sung >= p:
			start = p
	return start


## True once note `index` has been missed: the view then shows its direction.
func hinted(index: int) -> bool:
	return int(miss_counts.get(index, 0)) >= 1


func press(note: Note) -> Result:
	if done:
		return Result.IGNORED
	if note == needed_for(sung):
		sung += 1
		if sung >= SONG.size():
			done = true
			return Result.DONE
		if PHRASES.has(sung):
			return Result.PHRASE_DONE
		return Result.NEXT
	mistakes += 1
	miss_counts[sung] = int(miss_counts.get(sung, 0)) + 1
	sung = phrase_start()
	return Result.WRONG


func reset() -> void:
	sung = 1
	mistakes = 0
	miss_counts.clear()
	done = false
