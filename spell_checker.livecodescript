script "community.livecode.trevordevore.spellchecker.library"

constant kVersion = "0.9.3"
constant kCategoryLetter = "letter"
constant kCategoryNumber = "number"
constant kCategoryPunctuation = "punctuation"
constant kCategoryWhitespace = "whitespace"
constant kCategoryNonBreaking = "non-breaking"
constant kCategoryApostrophe = "apostrophe"
constant kApostrophes = "'’"

local sTLDsA
local sRootDictionariesFolders
local sLanguage
local sAddWordsFile
local sWordChars


on libraryStack
  if the target is not me then pass libraryStack

  if the platform is "macos" then
    get NSSpellCheckerInitialize()
  else
    local tTLDsA
    put "com,edu,gov,io,local,mil,net,org,au,ca,cf,cn,de,es,eu,fr,ga,nl,nz,ru,tk,tv,uk,us" into sTLDsA
    split sTLDsA by "," and "="
  end if
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack

  if the platform is not "macos" then
    // Cleanup after the extension
    get hunspellDestroy()
  end if
end releaseStack


/**
Summary: Return the library version.

Returns: nothing
*/
function spellCheckerVersion
  return kVersion
end spellCheckerVersion


/**
Summary: Initializes the spell checker library.

Parameters:
pRootDictionaryFolders: Path to folder that contains folders of dictionaries.
pLanguage: The language to load.
pAddWordsFile: Path to file where words that user adds to dictionary will be stored.

Description:
All dictionaries should be hunspell dictionaries and the dictionary and affix files
must be encoded as UTF-8.

All parameters are ignored on macOS as the system spell checker is used.

You do not need to call this handler on macOS as it is called by default when the
library script is put in use.

Returns: Error message
*/
command spellcheckerInitialize pRootDictionaryFolders, pLanguage, pAddWordsFile
  if the platform is "macos" then
    get NSSpellCheckerInitialize()
    return empty
  else
    local tError

    put pRootDictionaryFolders into sRootDictionariesFolders

    if pLanguage is not empty then
      _loadDictionaryForLanguage pLanguage
      put the result into tError

      if tError is empty then
        _loadUserWordFile pAddWordsFile
        put the result into tError
      end if
    end if

    return tError
  end if
end spellcheckerInitialize


/**
Summary: Sets the language to use with the spell checker library.

Parameters:
pLanguage: The language to use when spell checking. On macOS you can pass in "automatic" to automatically identify the language to use.

Description:
Returns true if the language could be changed.

Returns: Error message
*/
command spellcheckerSetLanguage pLanguage, pAddWordsFile
  if the platform is "macos" then
    if pLanguage is "automatic" then
      get NSSpellCheckerSetAutomaticallyIdentifiesLanguages(true)
    else
      if not NSSpellCheckerSetLanguage(pLanguage) then
        return "language is not one of the available languages"
      else
        get NSSpellCheckerSetAutomaticallyIdentifiesLanguages(false)
      end if
    end if
    return empty
  else
    if pLanguage is "automatic" then
      return quote & "automatic" & quote && "is not a valid language on this platform"
    else
      local tError

      put pLanguage into sLanguage

      _loadDictionaryForLanguage pLanguage
      put the result into tError

      if tError is empty then
        _loadUserWordFile pAddWordsFile
        put the result into tError
      end if

      return tError
    end if
  end if
end spellcheckerSetLanguage


/**
Summary: Returns the language being used for spell checking.

Returns: String
*/
function spellcheckerGetLanguage
  if the platform is "macos" then
    if NSSpellCheckerGetAutomaticallyIdentifiesLanguages() then
      return "automatic"
    else
      return NSSpellCheckerGetLanguage()
    end if
  else
    return sLanguage
  end if
end spellcheckerGetLanguage


/**
Summary: Returns the WORDCHARS value.

Description:
WORDCHARS is set using `spellcheckerLoadWordCharsFromAffixFile` or `spellcheckerSetWordChars`.
Not applicable on macOS.

Returns: String
*/
function spellcheckerGetWordChars
  if the platform is "macos" then
    return empty
  else
    return sWordChars
  end if
end spellcheckerGetWordChars


/**
Summary: Loads a Hunspell dictionary for a language.

Parameters:
pLanguage: The language to load. Must match name of a dictionary folder.

Description:
Looks for the dictionary in the `sRootDictionariesFolders` folder.

Returns: True if the language was successfully initialized.
*/
private command _loadDictionaryForLanguage pLanguage
  local tError
  local wasInitialized = false
  local tFolder

  # Initialize with first .aff and .dic files found.
  # Load as many .dic files as possible.
  repeat for each line tFolder in sRootDictionariesFolders
    local tAffixFiles, tDictFiles

    put files(tFolder & "/" & pLanguage) into tAffixFiles
    put tAffixFiles into tDictFiles
    filter tAffixFiles with "*.aff"
    filter tDictFiles with "*.dic"

    if tAffixFiles is not empty then
      _loadWordCharsFromAffixFile tFolder & "/" & pLanguage & "/" & line 1 of tAffixFiles
      put the result into tError

      if tError is not empty then exit repeat
    end if

    if tAffixFiles is not empty then
      hunspellInitialize \
            tFolder & "/" & pLanguage & "/" & line 1 of tAffixFiles, \
            tFolder & "/" & pLanguage & "/" & line 1 of tDictFiles

      # Load additional dict files
      local tLineNo, tRslt
      repeat with tLineNo = 2 to the number of lines of tDictFiles
        put hunspellAddDic(tFolder & "/" & pLanguage & "/" & line tLineNo of tDictFiles) into tRslt
        if tRslt is 1 then
          # dictionary slots are full.
          exit repeat
        end if
      end repeat

      put true into wasInitialized
      exit repeat
    end if
  end repeat

  if tError is empty and not wasInitialized then
    put "dictionary folder for language" && pLanguage && "was not found" into tError
  end if

  return tError for error
end _loadDictionaryForLanguage


/*
Summary: Find and load the WORDCHARS variable in an affix file.

Description:
A Huspell Affix file (.aff) has a `WORDCHARS` setting which lists additional
characters that should be considered part of a word. The Hunspell C API does
not provide access to this setting (only the C++ does) so it needs to be manually
extracted from the `.aff` file and then set using this command.

Returns: Error message
*/
command _loadWordCharsFromAffixFile pAffixFile
  local tError

  open file pAffixFile for "utf-8" text read
  put the result into tError
  if tError is not empty then
    put "unable to open affix file" && quote & pAffixFile & quote & ":" && tError into tError
  end if

  if tError is empty then
    repeat forever
      read from file pAffixFile for 1 line
      if the result is "EOF" then exit repeat
      put the result into tError
      if tError is not empty then
        put "unable to read from affix file" && quote & pAffixFile & quote & ":" && tError into tError
        exit repeat
      end if

      if it begins with "WORDCHARS" then
        put word 1 to -1 of (char 10 to -1 of it) into sWordChars
        exit repeat
      end if
    end repeat

    close file pAffixFile
  end if

  return tError
end _loadWordCharsFromAffixFile


/**
Summary: Loads the user word file with additional words that have been added.

Returns: Error message
*/
private command _loadUserWordFile pAddWordsFile
  local tError

  put pAddWordsFile into sAddWordsFile

  local tFile
  put _userWordsFile() into tFile
  if there is a file tFile then
    local tWords, tWord

    put _readFileContents(tFile) into tWords
    if the result is not empty then
      put "unable to read in user word file:" && the result into tError
    else
      repeat for each line tWord in tWords
        get hunspellAdd(tWord)
      end repeat
    end if
  end if

  return tError
end _loadUserWordFile


/**
Summary: Return the path to the file where user words are stored.

Returns: File path or empty if it hasn't been set.
*/
private function _userWordsFile
  return sAddWordsFile
end _userWordsFile


/**
Summary: Checks the spelling of a word.

Parameters:
pWord: The word to check.

Description:
This function checks `pWord` to see if it is spelled correctly.
Returns true if it is, false if it isn't.

Returns: Boolean
*/
function spellcheckerCheckWord pWord
  if the platform is "macos" then
    return spellcheckerFindMisspelledWords(pWord, 1) is empty
  else
    return hunspellSpell(pWord)
  end if
end spellcheckerCheckWord


/**
Summary: Add a word to the dictionary.

Parameters:
pWord: The word to add.

Returns: Error Message
*/
command spellcheckerLearnWord pWord
  if the platform is "macos" then
    get NSSpellCheckerLearnWord(pWord)
    return empty
  else
    local tError, tFile

    # Append word to user dictionary file
    put _userWordsFile() into tFile
    if tFile is not empty then
      open file tFile for "utf-8" text append
      put the result into tError
      if tError is empty then
        write pWord & cr to file tFile
        put the result into tError

        close file tFile
      end if
    end if

    if tError is empty then
      get hunspellAdd(pWord)
      return empty for value
    else
      return tError for error
    end if
  end if
end spellcheckerLearnWord


/**
Summary: Removes a word from the dictionary.

Parameters:
pWord: The word to remove.

Returns: Error Message
*/
command spellcheckerUnlearnWord pWord
  if the platform is "macos" then
    get NSSpellCheckerUnlearnWord(pWord)
    return empty
  else
    local tError, tFile

    # Append word to user dictionary file
    put _userWordsFile() into tFile
    if tFile is not empty then
      local tWordList
      local tLineNo
      local tSaveChanges = false

      put _readFileContents(tFile) into tWordList
      put the result into tError

      if tError is empty then
        set the wholematches to true

        repeat forever
          put lineOffset(pWord, tWordList) into tLineNo
          if tLineNo > 0 then
            delete line tLineNo of tWordlist
            put true into tSaveChanges
          else
            exit repeat
          end if
        end repeat
      end if

      if tSaveChanges then
        open file tFile for "utf-8" text write
        put the result into tError
        if tError is empty then
          write tWordlist to file tFile
          put the result into tError

          close file tFile
        end if
      end if
    end if

    if tError is empty then
      get hunspellRemove(pWord)
      return empty for value
    else
      return tError for error
    end if
  end if
end spellcheckerUnlearnWord


/**
Summary: Adds a word to the list of words to ignore for the current session.

Parameters:
pWord: The word to ignore.

Description:
The word will be ignored for the current session. It will not be added to the
user dictionary.

Returns: nothing
*/
command spellcheckerIgnoreWord pWord
  if the platform is "macos" then
    get NSSpellCheckerIgnoreWord(pWord, 0)
  else
    get hunspellAdd(pWord)
  end if
  return empty
end spellcheckerIgnoreWord


/**
Summary: Return a list of languages that can be used with the spell checker.

Description:
On macOS it is the list of languages provided by the operating system.

On non-macOS systems this will be the list of folders in the dictionary folders that were
passed to spellcheckerInitialize.

Returns: CR-delimited list of language names
*/
function spellcheckerAvailableLanguages
  if the platform is "macos" then
    # Let the extension handle it
    pass spellcheckerAvailableLanguages
  else
    local tFolders, tFolder
    local tTempFolders, tPossibleFolder

    set the wholematches to true

    repeat for each line tFolder in sRootDictionariesFolders
      put folders(tFolder) into tTempFolders
      filter tTempFolders without ".*"

      repeat for each line tPossibleFolder in tTempFolders
        if tPossibleFolder is not among the lines of tFolders then
          put tPossibleFolder & cr after tFolders
        end if
      end repeat
    end repeat
    delete the last char of tFolders

    sort lines of tFolders ascending international

    return tFolders
  end if
end spellcheckerAvailableLanguages


/**
Summary: Finds and flags misspelled words in a field.

Parameters:
pField: The long id of a field.

Description:
Passes the text of `pField` to `spellcheckerFindMisspelledWords` and sets the
`flaggedRanges` to the result.

Returns: Return value from `spellcheckerFindMisspelledWords`
*/
command spellcheckerFlagMisspelledWordsInField pField
  local tRanges
  put spellcheckerFindMisspelledWords(the text of pField, 1) into tRanges
  set the flaggedRanges of pField to tRanges
  return tRanges
end spellcheckerFlagMisspelledWordsInField


/**
Summary: Spell checks the words in a string.

Parameters:
pString: The string to spell check.
pOffset: The character offset to start spell checking from. Default is 1.

Description:
The return value can be assigned to the `flaggedRanges` property of a field.

Returns: CR-delimited list of character indices representing the start and end of misspelled words.
*/
function spellcheckerFindMisspelledWords pString, pOffset
  if the platform is "macos" then
    local tLanguage
    local tRangeList
    local tWrap = false
    local tDocTag = 0

    put spellcheckerCheckSpellingOfStringWithOptions(pString, pOffset, tLanguage, tWrap, tDocTag) into tRangeList
  else
    put _hunspellFindMisspelledWords(pString, pOffset) into tRangeList
  end if

  return tRangeList
end spellcheckerFindMisspelledWords


/**
Summary: Checks to see if the user just finished typing a word and spell checks it if they did.

Description:
If no text is selected and the selectedChunk is preceded by a character that ends a word then
the previous word will be spell checked and flagged if misspelled.

If there is a word character directly following the insertion point then that will be spell checked
as well.

Returns: nothing
*/
command spellcheckerCheckLastWordTypedByUser
  local tChunk

  put the selectedChunk into tChunk

  # Only check if there is no selected text.
  if word 4 of tChunk < word 2 of tChunk then
    local tId, tCharNum
    local spellCheckLastWord = false
    local tField

    put the long id of the target into tField
    put word 4 of tChunk into tCharNum
    put the short id of the selectedField into tId

    put _characterMightEndWord(character tCharNum of field id tId) into spellCheckLastWord

    if spellCheckLastWord then
      local tFirstStrChar, tLastStrChar, tStr, tAnchorOffset, tChar, i

      # Make sure end of word char doesn't carry over flagged setting
      if tCharNum > 0 then
        set the flagged of character tCharNum of field id tId to false
      end if

      _charsWithinInnerWhiteSpaceBoundaries the text of field id tId, tCharNum-1, tFirstStrChar, tLastStrChar, tStr, tAnchorOffset
      if tFirstStrChar > 0 then
        if _stringIsURL(tStr) then
          set the flagged of character tFirstStrChar to tLastStrChar of field id tId to false
        else
          local tFirstWordChar, tLastWordChar, tWord

          _findWordWithinString tStr, tAnchorOffset, tFirstStrChar, tFirstWordChar, tLastWordChar, tWord
          if tFirstWordChar > 0 then
            send "__spellcheckerCheckWord tField, tWord, tFirstWordChar, tLastWordChar" to the target in 10 milliseconds
          end if
        end if
      end if
    end if
  end if

  return empty
end spellcheckerCheckLastWordTypedByUser


/**
Summary: Spell check the first word in `the selecteChunk`.

Returns: nothing
*/
command spellcheckerCheckSelectedWord
  local tChunk, tText, tId, tOffset
  local tFirstStrChar, tLastStrChar, tStr, tAnchorOffset

  # Early exit if
  # 1. No selection
  # 2. If any non-word characters are selected.
  # 3. If selection is surrounded by letters or numbers signifying an incomplete selection
  put the selectedChunk into tChunk
  if word 2 of tChunk > word 4 of tChunk then return empty
  put the short id of the selectedField into tId

  put the selectedText into tText
  repeat for each char tChar in the selectedText
    if _characterEndsWord(tChar) then
      return empty
    end if
  end repeat

  put char (word 2 of tChunk - 1) of field id tId into tChar
  if tChar is not empty and _codepointCategory(codepoint 1 of tChar) \
        is among the items of (kCategoryLetter &","& kCategoryNumber) then
    return empty
  end if

  put char (word 4 of tChunk + 1) of field id tId into tChar
  if tChar is not empty and _codepointCategory(codepoint 1 of tChar) \
        is among the items of (kCategoryLetter &","& kCategoryNumber) then
    return empty
  end if

  # Now check word
  put word 2 of tChunk - 1 into tOffset

  _charsWithinInnerWhiteSpaceBoundaries tText, 1, tFirstStrChar, tLastStrChar, tStr, tAnchorOffset

  if tFirstStrChar > 0 then
    if _stringIsURL(tStr) then
      set the flagged of char (tOffset+tFirstStrChar) to (tOffset+tLastStrChar) of field id tId to false
    else
      local tFirstWordChar, tLastWordChar, tWord

      _findWordWithinString tStr, tAnchorOffset, tFirstStrChar, tFirstWordChar, tLastWordChar, tWord

      if tFirstWordChar > 0 then
        add tOffset to tFirstWordChar
        add tOffset to tLastWordChar

        set the flagged of character tFirstWordChar to tLastWordChar \
              of field id tId to not spellcheckerCheckWord(tWord)
      else
        set the flagged of character tFirstStrChar to tLastStrChar \
              of field id tId to false
      end if
    end if
  end if
end spellcheckerCheckSelectedWord


/**
Summary: Spell checks word surrounding insertion point when there is no text selection.

Description:
If no text is selected then this handler will find the word surrounding
the insertion point and spell check it.

Returns: nothing
*/
command spellcheckerCheckWordAroundInsertionPoint
  local tChunk

  put the selectedChunk into tChunk

  # Only check if there is no selected text.
  if word 4 of tChunk < word 2 of tChunk then
    local tId, tCharNum
    local spellCheckLastWord = false

    put the short id of the selectedField into tId

    local tAnchorChar, tFirstStrChar, tLastStrChar
    local tStr, tAnchorOffset

    ## look for range to check
    put max(1, word 4 of tChunk) into tAnchorChar

    _charsWithinInnerWhiteSpaceBoundaries the text of field id tId, tAnchorChar, tFirstStrChar, tLastStrChar, tStr, tAnchorOffset
    if tFirstStrChar > 0 then
      if _stringIsURL(tStr) then
        set the flagged of character tFirstStrChar to tLastStrChar of field id tId to false
      else
        local tFirstWordChar, tLastWordChar, tWord

        _findWordWithinString tStr, tAnchorOffset, tFirstStrChar, tFirstWordChar, tLastWordChar, tWord
        if tFirstWordChar > 0 then
          set the flagged of character tFirstWordChar to tLastWordChar of field id tId to not spellcheckerCheckWord(tWord)
        else
          set the flagged of the selectedchunk to false
        end if
      end if
    else
      set the flagged of the selectedchunk to false
    end if
  end if

  return empty
end spellcheckerCheckWordAroundInsertionPoint


/**
Summary: Returns the property of a character based on the first codepoint.

Returns: letter | number | punctuation | apostrophe | whitespace | non-breaking
*/
function spellcheckerCharacterProperty pCharacter
  if pCharacter is not empty then
    return _codepointCategory(codepoint 1 of pCharacter)
  else
    return empty
  end if
end spellcheckerCharacterProperty


/**
Summary: Checks whether or not the spell checker considers a string a url. URLs are not spell checked.

Parameters:
pString: The string to check.

Description:
A string is considered a url if it has `://`, `:\\`, or `@`.

Returns: Boolean
*/
function spellCheckerIsURL pString
  return _stringIsURL(pString)
end spellCheckerIsURL


/**
Summary: Called "in time" so that spell checking doesn't slow down users typing.

Returns: nothing
*/
command __spellcheckerCheckWord pField, pWord, pStartChar, pEndChar
  if there is a pField then
    set the flagged of character pStartChar to pEndChar of pField to not spellcheckerCheckWord(pWord)
  end if
end __spellcheckerCheckWord


/**
Summary: Returns true if the character might end a word.

Description:
The "might" comes from the inclusion of apostrophe.

Returns: Boolean
*/
private function _characterMightEndWord pCharacter
  return pCharacter is not empty and \
        _codepointCategory(codepoint 1 of pCharacter) is among the items of \
        (kCategoryPunctuation & "," & kCategoryWhitespace & "," & kCategoryApostrophe) \
        and pCharacter is not among the characters of sWordChars
end _characterMightEndWord


/**
Summary: Returns true if the character definitely ends a word.

Description:
Does not include apostrophe.

Returns: Boolean
*/
private function _characterEndsWord pCharacter
  return pCharacter is not empty and \
        _codepointCategory(codepoint 1 of pCharacter) is among the items of \
        (kCategoryPunctuation & "," & kCategoryWhitespace) \
        and pCharacter is not among the characters of sWordChars
end _characterEndsWord


/**
Summary: Finds the first and last chars that make up the string between whitespace.

Parameters:
pText: The text to search.
pAnchorCharNo: The character number to start the search from.
rFirstChar: > 0 if a string was found.
rLastChar: > 0 if a string was found.
rString: The string that was found.
rAnchorOffset: The value of `pAnchorCharNo` relative to the start of `rString`. Pass as `pAnchorCharNo` param to `_findWordWithinString`.

Returns: nothing
*/
private command _charsWithinInnerWhiteSpaceBoundaries pText, pAnchorCharNo, @rFirstChar, @rLastChar, @rString, @rAnchorOffset
  local tChar
  local tIndex, tStrLen

  put 0 into rFirstChar
  put 0 into rLastChar
  put empty into rString
  put 0 into rAnchorOffset

  put the number of characters in pText into tStrLen
  if tStrLen is 0 then return empty

  # Find the character to start building from
  put pAnchorCharNo into tIndex

  repeat while tIndex > 0
    put character tIndex of pText into tChar
    if tChar is not empty and _codepointCategory(codepoint 1 of tChar) is not kCategoryWhitespace then
      subtract 1 from tIndex

      if tIndex < 1 then
        put 1 into rFirstChar
        if pAnchorCharNo is tStrLen then
          put pAnchorCharNo into rLastChar
        else
          put pAnchorCharNo+1 into tIndex
        end if
        exit repeat
      end if
    else if tIndex < pAnchorCharNo then
      put tIndex+1 into rFirstChar
      if pAnchorCharNo is tStrLen then
        put pAnchorCharNo into rLastChar
      else
        put pAnchorCharNo+1 into tIndex
      end if
      exit repeat
    else
      exit repeat
    end if
  end repeat

  if rFirstChar is 0 then
    put pAnchorCharNo+1 into tIndex
    repeat while tIndex <= tStrLen
      put character tIndex of pText into tChar
      if tChar is not empty and _codepointCategory(codepoint 1 of tChar) is not kCategoryWhitespace then
        put tIndex into rFirstChar
        add 1 to tIndex
        exit repeat
      else
        add 1 to tIndex
      end if
    end repeat
  end if

  # Now find the end
  if rFirstChar > 0 and rLastChar is 0 then
    repeat while tIndex <= tStrLen
      put character tIndex of pText into tChar
      if tChar is not empty and _codepointCategory(codepoint 1 of tChar) is not kCategoryWhitespace then
        add 1 to tIndex

        if tIndex > tStrLen then
          put tStrLen into rLastChar
          exit repeat
        end if
      else
        put tIndex-1 into rLastChar
        exit repeat
      end if
    end repeat
  end if

  if rFirstChar > 0 and rLastChar > 0 then
    put character rFirstChar to rLastChar of pText into rString
  end if

  # Adjust offset so that it is 1 based relative to rString
  put max(1, pAnchorCharNo - rFirstChar + 1) into rAnchorOffset

  return empty
end _charsWithinInnerWhiteSpaceBoundaries


/**
Summary: Finds a word to spell check within a string.

Parameters:
pString: The string to search for a word.
pAnchorCharNo: Start searching from this character.
pOffset: The offset of the start of `pString` within the field it was extracted from. Used to return a field relative value for `rFirstChar` and `rLastChar`.
rFirstChar: > 0 if a word was found.
rLastChar: > 0 if a word was found.
rWord: The word that was found.

Description:
`pString` is extracted using the results from `_charsWithinInnerWhiteSpaceBoundaries`.
It is assumed it has no whitespace and that it is not a url.

Returns: nothing
*/
private command _findWordWithinString pString, pAnchorCharNo, pOffset, @rFirstChar, @rLastChar, @rWord
  local tChar, tCategory
  local tIndex, tStrLen

  put 0 into rFirstChar
  put 0 into rLastChar

  put the number of characters in pString into tStrLen
  if tStrLen is 0 then return empty

  # Find the character to start building from
  put pAnchorCharNo into tIndex

  repeat while tIndex > 0
    if _charIsPartOfWord(pString, tStrLen, tIndex) then
      subtract 1 from tIndex

      if tIndex < 1 then
        put 1 into rFirstChar
        if pAnchorCharNo is tStrLen then
          put pAnchorCharNo into rLastChar
        else
          put pAnchorCharNo+1 into tIndex
        end if
        exit repeat
      end if
    else if tIndex < pAnchorCharNo then
      put tIndex+1 into rFirstChar
      if pAnchorCharNo is tStrLen then
        put pAnchorCharNo into rLastChar
      else
        put pAnchorCharNo+1 into tIndex
      end if
      exit repeat
    else
      exit repeat
    end if
  end repeat

  if rFirstChar is 0 then
    put pAnchorCharNo+1 into tIndex
    repeat while tIndex <= tStrLen
      if _charIsPartOfWord(pString, tStrLen, tIndex) then
        put tIndex into rFirstChar
        add 1 to tIndex
        exit repeat
      else
        add 1 to tIndex
      end if
    end repeat
  end if

  # Now find the end
  if rFirstChar > 0 and rLastChar is 0 then
    repeat while tIndex <= tStrLen
      if _charIsPartOfWord(pString, tStrLen, tIndex) then
        add 1 to tIndex

        if tIndex > tStrLen then
          put tStrLen into rLastChar
          exit repeat
        end if
      else
        put tIndex-1 into rLastChar
        exit repeat
      end if
    end repeat
  end if

  if rFirstChar > 0 and rLastChar > 0 then
    put character rFirstChar to rLastChar of pString into rWord
    add pOffset-1 to rFirstChar
    add pOffset-1 to rLastChar
  end if

  return empty
end _findWordWithinString


private function _charIsPartOfWord pString, pStrLen, pCharNo
  local tChar, tCategory

  put character pCharNo of pString into tChar
  put _codepointCategory(codepoint 1 of tChar) into tCategory
  # kCategoryLetter or kCategoryNumber? Keep scanning.
  # kCategoryPunctuation? Done scanning.
  # kCategoryApostrophe? If preceding character is kCategoryLetter or kCategoryNumber then keep scanning.
  if tCategory is kCategoryPunctuation then
    return false
  else if tCategory is kCategoryApostrophe then
    if pCharNo is 1 or pCharNo is pStrLen then
      return false
    else if _codepointCategory(codepoint 1 of char pCharNo-1 of pString) \
          is not among the items of (kCategoryLetter &","& kCategoryNumber) then
      return false
    else if _codepointCategory(codepoint 1 of char pCharNo+1 of pString) \
          is not among the items of (kCategoryLetter &","& kCategoryNumber) then
      return false
    else
      return true
    end if
  else
    return true
  end if
end _charIsPartOfWord


private function _stringIsURL pString
  return pString contains "://" \
        or pString contains ":\\" \
        or pString contains "@"
end _stringIsURL


/**
Summary: Return a sequence of start+end character indices for each word in `pText`.

Parameters:
pText: The string to spell check.

Description:
This function will find an spell check each word in `pText`. If a misspelled word
is found then a COMMA-delimited list of the start+end character numbers is added to
a CR-delimited list of ranges that will be returned.

The scanner will detect urls (strings with :// in them) and email addresses and not spell check them.
It will also look for a handful of common TLDs (e.g. .com, .edu, etc.) and not spell check
them either.

The returned value can be assigned to the `flaggedRanges` property of a field to
visually mark the misspelled words.

Returns: CR-delimited list of start+end character indices for misspelled words.
*/
private function _hunspellFindMisspelledWords pText, pOffset
  local tStrLen, tFirstStrChar, tLastStrChar, tStr, tAnchorOffset
  local tRanges

  put the number of characters in pText into tStrLen

  repeat while pOffset <= tStrLen
    _charsWithinInnerWhiteSpaceBoundaries pText, pOffset, tFirstStrChar, tLastStrChar, tStr, tAnchorOffset
    if tFirstStrChar > 0 then
      if _stringIsURL(tStr) then
        put tLastStrChar + 1 into pOffset
      else
        local tFirstWordChar, tLastWordChar, tWord

        _findWordWithinString tStr, tAnchorOffset, tFirstStrChar, tFirstWordChar, tLastWordChar, tWord
        if tFirstWordChar > 0 then
          if not hunspellSpell(tWord) then
            put tFirstWordChar & "," & tLastWordChar & cr after tRanges
          end if

          put tLastWordChar + 1 into pOffset
        else
          put tLastStrChar + 1 into pOffset
        end if
      end if
    else
      exit repeat
    end if
  end repeat

  delete the last char of tRanges
  return tRanges
end _hunspellFindMisspelledWords


/**
Summary: Classify codepoint as one of letter, number, or punctuation.

Parameters:
pCodepoint: The codepoint to check.

Description:
Based on code provided by the LiveCode team.

Returns: Classification string. See constants.
*/
private function _codepointCategory pCodepoint
  # check if non-breaking space
  if pCodepoint is numToCodepoint(160) then
    # For spell check purposes this is white space
    return kCategoryWhitespace
  else if pCodepoint is among the chars of kApostrophes then
    return kCategoryApostrophe
  end if

  local tCategory
  put codepointProperty(pCodepoint, "General_Category") into tCategory
  if tCategory ends with "Letter" then
    return kCategoryLetter
  else if tCategory ends with "Number" then
    return kCategoryNumber
  else
    if codepointProperty(pCodepoint, "White_Space") then
      return kCategoryWhitespace
    end if
    return kCategoryPunctuation
  end if
end _codepointCategory


/**
Summary: Detects some common TLDs to determine if a word should be spell checked.

Parameters:
pWord: The word to check.

Description:
If a word ends in a TLD then it should not be spell checked.
The current implementation does not contain an exhaustive list by any means.

Returns: Boolean
*/
private function _wordHasDomain pWord
  set the itemDelimiter to "."
  return item -1 of pWord is among the keys of sTLDsA
end _wordHasDomain


/**
Summary: Read in the contents of a file.

Parameters:
pFilename: The file to read. File contents are encoded as UTF-8.

Returns:
it: File contents
result: Error message
*/
private function _readFileContents pFilename
  local tError

  open file pFilename for "utf-8" text read
  put the result into tError

  if tError is empty then
    read from file pFilename until eof
    if the result is not "eof" then
      put the result into tError
    end if

    close file pFilename
  end if

  if tError is empty then
    return it for value
  else
    return tError && "(" & pFilename & ")" for error
  end if
end _readFileContents
