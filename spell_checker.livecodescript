script "community.livecode.trevordevore.spellchecker.library"

constant kVersion = "0.9.0"
constant kCategoryLetter = "letter"
constant kCategoryNumber = "number"
constant kCategoryPunctuation = "punctuation"
constant kCategoryWhitespace = "whitespace"
constant kCategoryNonBreaking = "non-breaking"

local sTLDsA
local sRootDictionariesFolders
local sLanguage
local sAddWordsFile


on libraryStack
  if the target is not me then pass libraryStack

  if the platform is "macos" then
    get NSSpellCheckerInitialize()
  else
    local tTLDsA
    put "com,edu,gov,io,local,mil,net,org,au,ca,cf,cn,de,eu,fr,ga,nl,nl,ru,tk,tv,uk,us" into sTLDsA
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

  if not wasInitialized then
    put "dictionary folder for language" && pLanguage && "was not found" into tError
  end if

  return tError for error
end _loadDictionaryForLanguage


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

Based on code provided by the LiveCode team.

Returns: CR-delimited list of start+end character indices for misspelled words.
*/
private function _hunspellFindMisspelledWords pText, pOffset
  constant kJoinLetter = ".'’"
  constant kJoinNumber = ".-,/"
  constant kJoinEmail = "@"
  constant kJoinDomain = "."

  local tStartIndex
  local tRanges
  local tLength
  local tInsideURL = false
  local tPotentialDomain = false

  put the number of characters in pText into tLength

  put max(1, pOffset) into tStartIndex
  repeat while tStartIndex <= tLength
    // skip to word start
    local tCategory

    put _codepointCategory(codepoint 1 of char tStartIndex of pText) into tCategory

    repeat while tStartIndex < tLength
      if tCategory is not kCategoryWhitespace and tCategory is not kCategoryPunctuation then
        exit repeat
      end if
      add 1 to tStartIndex
      put _codepointCategory(codepoint 1 of char tStartIndex of pText) into tCategory
    end repeat

    if tStartIndex > tLength or tCategory is kCategoryWhitespace or tCategory is kCategoryPunctuation then
      exit repeat
    end if

    /*
      Rules for spell checking URLs, emails, and domains:
      1. Once user has typed :// or the @ character between letters or numbers then scanner is inside of a url
         and spell checking is turned off until white space is encountered again.
      2. If scanner is not in a url and user types char|num.char|num then check for potential domain.
     */

    local tEndIndex
    put tStartIndex into tEndIndex

    // look for end of word
    repeat while tEndIndex < tLength
      local tNextCharacter
      put character (tEndIndex + 1) of pText into tNextCharacter

      local tNextCategory
      put _codepointCategory(codepoint 1 of tNextCharacter) into tNextCategory
      if tNextCategory is kCategoryLetter or tNextCategory is kCategoryNumber or tNextCategory is kCategoryNonBreaking \
            or (tInsideURL and tNextCategory is not kCategoryWhitespace) then
        # Continue with word
        add 1 to tEndIndex
        put tNextCategory into tCategory
      else if tInsideURL and tNextCategory is kCategoryWhitespace then
        # End of url
        exit repeat
      else if tEndIndex < tLength - 1 then
        # Look for special joins characters that continue same word or signify a url, email, or domain.
        local tThirdCharacter
        put character (tEndIndex + 2) of pText into tThirdCharacter
        put _codepointCategory(codepoint 1 of tThirdCharacter) into tNextCategory

        if tNextCharacter is ":" and tThirdCharacter is "/" and character tEndIndex+3 of pText is "/" then
          # Found url
          put true into tInsideURL
          add 3 to tEndIndex
        else if (tNextCharacter is kJoinEmail or tNextCharacter is kJoinDomain) \
              and (tCategory is kCategoryNumber or tCategory is kCategoryLetter) \
              and (tNextCategory is kCategoryNumber or tNextCategory is kCategoryLetter) then
          # Found email (treat as url) or domain
          put tNextCharacter is kJoinEmail into tInsideURL
          put tNextCharacter is kJoinDomain into tPotentialDomain
          add 2 to tEndIndex
        else if tNextCategory is tCategory and \
              ((tCategory is kCategoryNumber and tNextCharacter is among the characters of kJoinNumber) or \
              (tCategory is kCategoryLetter and tNextCharacter is among the characters of kJoinLetter)) then
          # Continue with word. E.g. char.char, char'char, num.num, num/num, etc.
          add 2 to tEndIndex
        else
          exit repeat
        end if
      else
        put false into tInsideURL
        exit repeat
      end if
    end repeat

    local tWord
    local tSpellCheckWord
    put character tStartIndex to tEndIndex of pText into tWord
    put not tInsideURL and (not tPotentialDomain or not _wordHasDomain(tWord)) into tSpellCheckWord

    if tSpellCheckWord then
      if not hunspellSpell(tWord) then
        put tStartIndex & "," & tEndIndex & cr after tRanges
      end if
    end if

    put false into tInsideURL
    put false into tPotentialDomain

    put tEndIndex + 1 into tStartIndex
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
  // check if non-breaking space
  if pCodepoint is numToCodepoint(160) then
    return kCategoryNonBreaking
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
