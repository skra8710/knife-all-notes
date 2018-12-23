--
-- Note-bend all notes by knifing first part of each long enough note
--

--
-- Sakura
-- August 18, 2018
--

--
-- Manifest
--
function manifest()
    myManifest = {
        name          = "Pickup Note",
        comment       = "Knife everything",
        author        = "Sakura",
        pluginID      = "{968fff77-66ed-4a55-a7db-d3a1eeee37f1}", --GUID generator
        pluginVersion = "1.0",
        apiVersion    = "3.0.1.0"
    }
    
    return myManifest
end

-- these came with the knifetool program
-- noteevents
phtbl = {"V", "{", "@", "i:", "I", "U", "u:", "e", "Q", "O:", "Q@", "@r", "aI", "aU", "I@", "U@", "eI", "e@", "OI", "O@", "@U", "-"}

--- split function
function split(str, del)
	p, nrep = str:gsub("%s*"..del.."%s*", "")
	return { str:match((("%s*(.-)%s*"..del.."%s*"):rep(nrep).."(.*)")) }
end

-- pickup note
function pickupNote(length, pitch, phon, note)
    pickup = {}
    pickup.durTick = length
    pickup.phonemes = phon
    pickup.posTick = note.posTick
    pickup.lyric = note.lyric
    pickup.noteNum = pitch
    pickup.velocity = note.velocity
    
    return pickup
end

-- 
-- Main Function
--
function main(processParam, envParam)
    -- get list of notes in part
    -- Lua is cursed, it starts counting from 1
    k = 1
    local noteList = {}
	VSSeekToBeginNote()
	retCode, note = VSGetNextNoteEx()
    while (retCode == 1) do
        noteList[k] = note
        k = k + 1
        retCode, note = VSGetNextNoteEx()
    end
    
    -- return if there are no notes
    noteCount = table.getn(noteList)
    if(noteCount == 0) then
        VSMessageBox("No notes!", 0)
        return 0
    end
    
    -- decide how long each pickup note should be with the dialogue box
	VSDlgSetDialogTitle("Pickup Note Length")
    local field = {}
    field.name       = "pnoteLength"
	field.caption    = "Length"
	field.initialVal = 45
	field.type = 0
    -- field types
    --      1: checkbox (just one, caption is next to checkbox)
    --      4: dropdown, options are initialVal split at commas
    --      2: text input, strings
    --      0: text input, numerical
	dlgStatus  = VSDlgAddField(field)
	dlgStatus = VSDlgDoModal()
	if (dlgStatus == 2) then
		-- When it was cancelled.
		return 0
	end
	if ((dlgStatus ~= 1) and (dlgStatus ~= 2)) then
		-- When it returned an error.
		return 1
	end
    
    dlgStatus, pickuplen = VSDlgGetIntValue("pnoteLength")
    
    -- for each note, decide if note is long enough to knife
    
    -- loop through musical part until you're done
    len = 0 -- num of separate phonemes in note
    lenp = #phtbl   -- length of phtbl, for iteration
    prev = {}
    dist = 300
    errors = 0  -- total errors (for debugging)
	for k = 1, noteCount do
        if (noteList[k].durTick >= pickuplen * 2) then
            -- this is the knife part, copied from knifetool2B code
            
            --  find where the split is and save in phonep, phones
            oneNote = {}
            twoNote = noteList[k]
            phoneCV = split(twoNote.phonemes, " ")
            len = #phoneCV
            phix = 0
            phi = 0
            for i = 1 ,len do
                for ix = 1 ,lenp do
                    if phtbl[ix] == phoneCV[i] then
                        phi = i
                        phix = ix
                        break
                    end
                end
            end
            phonep = ""
            phones = "-"
            if (phix ~= 0) or (phi  ~= 0) then
                for i = 1 ,phi do
                    phonep = phonep.." "..phoneCV[i]
                end
                for i = phi+1 ,len do
                    phones = phones.." "..phoneCV[i]
                end
            end
            
            if phonep == "" then
                phonep = twoNote.phonemes
                phones = "-"
            end
            
            -- assign new note properties
            pitch = twoNote.noteNum - 2
            if(dist < 120) then
                pitch = prev.noteNum
            end
            
            oneNote = pickupNote(pickuplen, pitch, phonep, twoNote)
            
            twoNote.durTick = twoNote.durTick - pickuplen
            twoNote.posTick = twoNote.posTick + pickuplen
            twoNote.lyric = "-"
            twoNote.phonemes = phones
            
            --insert notes
            retCode = VSUpdateNote(twoNote)
            if (retCode ~= 1 ) then
                errors = errors + 1
            end
            
            retCode = VSInsertNote(oneNote)
            if (retCode ~= 1 ) then
                errors = errors + 1
            end
        end
        -- update comparison values
        prev = noteList[k]
        if(k < noteCount) then
            dist = noteList[k + 1].posTick - (prev.posTick + prev.durTick)
        end
    end
    
    VSMessageBox("Errors: "..errors, 0)
    return 0
end
