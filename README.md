# spellChecker for LiveCode

spellChecker is a spell checking library for LiveCode. It uses NSSpellChecker on macOS and Hunspell on Windows to provide spell checking functionality.

The API consists of all of the public handlers in the `spell_checker.livecodescript` file as well as handlers that begin with `spellchecker` in the `nsspellchecker.lcb` and `hunspell.lcb` files.

## Obtaining dictionaries that work with Hunspell

On macOS the system dictionaries are used so there is no configuration necessary.

On Windows you must distribute dictionaries with your application. You can find dictionaries that work with Hunspell in the following Github repo:

https://github.com/wooorm/dictionaries

## Initialization

### macOS

On macOS all initialization occurs when the `spell_checker.livecodescript` stack is put in use.

### Other Systems

On other platforms call `spellcheckerInitialize` and pass in the folder where dictionaries are stored, the dictionary language to load (the name of the dictionary folder), and the (optional) path to the file where words that the user adds to the dictionary will be stored. If you don't pass in the last parameter then the words will only be added to the in-memory dictionary during the current session.

```
put levureAppFolder() & "/assets/dictionaries" into tDictionariesFolder
put "en" into tLanguage
put userDictionaryFolder() & "/en_user_words.txt" into tAddWordsFile
spellcheckerInitialize tDictionariesFolder, tLanguage, tAddWordsFile
```

To change the language during a session call `spellcheckerSetLanguage`:

```
put "fr" into tLanguage
put userDictionaryFolder() & "/fr_user_words.txt" into tAddWordsFile
spellcheckerSetLanguage tLanguage, tAddWordsFile
```

## Marking misspelled words in a field

Spell checking an entire field is a single call. It will perform the spell check and flag the misspelled words.

```
spellcheckerFlagMisspelledWordsInField the long id of field "Document"
```

## Finding misspelled words in a string

You can also spell check a string and specify the character to start spell checking from.

```
put the text of field "Document" into tText
put 30 into tCharOffset
put spellcheckerFindMisspelledWords(tText, tCharOffset) into tCharRanges
set the flaggedRanges of field "Document" to tCharRanges
```

## Guessing Words

```
put spellcheckerGuessesForWord(tWord) into tGuesses
```

## List available dictionaries

If you would like to display a menu of dictionaries that the user can select from use `spellcheckerAvailableLanguages()`. This is usually only necessary on non-macOS systems.

```
put spellcheckerAvailableLanguages() into tLanguages
```

## Spell check while typing

The following example can be put in a frontscript and will spell check any field that returns `true` for the `uCheckSpelling` property. The code tries to enforce the following rules:

1. If user types a character that ends a word then previous word should be spell checked.
2. If user presses the delete or backspace key in a chunk whose `flagged` property is `true` then word surrounding the insertion point should be spell checked.
3. If user presses right arrow key to leave a word then previous word should be spell checked.
4. If user presses up or down arrow key and leaves a word then word should be spell checked.
5. If user double-clicks on a word then word should be spell checked.

Note that the example does not account for spell checking after the user cuts or pastes text. How you implement this will depend on how paste and cut are handled in your application. When pasting, the easiest solution is to spell check the whole field again using `spellcheckerFlagMisspelledWordsInField`, as a user can paste any amount of content and they can split up an existing word into multiple words. When cutting, you can use `spellcheckerCheckWordAroundInsertionPoint` after the text is cut.

```
local sUserDeletedText

on deleteKey
  if the uCheckSpelling of the target then
    put true into sUserDeletedText
  end if
  pass deleteKey
end deleteKey


on backspaceKey
  if the uCheckSpelling of the target then
    put true into sUserDeletedText
  end if
  pass backspaceKey
end backspaceKey


on textChanged
  # if screen isn't locked then textChanged messages further on down the chain
  # that might resize the field will cause screen flicker.
  lock screen

  if the uCheckSpelling of the target then
    lock screen
    if sUserDeletedText then
      put false into sUserDeletedText
      # Only update spelling if deleting characters in a misspelled word
      if the flagged of character (word 2 of the selectedchunk) of field id (the short id of the target) \
            or the flagged of character (word 4 of the selectedchunk) of field id (the short id of the target) then
        spellcheckerCheckWordAroundInsertionPoint
      end if
    else
      spellcheckerCheckLastWordTypedByUser
    end if
  end if
  pass textChanged
end textChanged


on arrowKey pKey
  # Account for user changing spelling and then exiting with up/down arrows
  if pKey is "up" or pKey is "down" then
    spellcheckerCheckWordAroundInsertionPoint
  end if
  pass arrowKey
end arrowKey


on rawKeyUp pKeyNum
  # Look to spell check word if uses right arrow.
  if pKeyNum is among the items of "65363" then
    spellcheckerCheckLastWordTypedByUser
  end if
  pass rawKeyUp
end rawKeyUp


on selectionChanged
  # Catches when user double-clicks on words
  if the uCheckSpelling of the target \
        and word 4 of the selectedChunk > word 2 of the selectedChunk then
    spellcheckerCheckSelectedWord
  end if
  pass selectionChanged
end selectionChanged
```

## Adding to your project

The repo is organized in the Levure Helper format so that it can be dropped right into the **helpers** folder of an app built on the Levure framework.

To use in a non-Levure project you will need to do the following:

1) Download the hunspell and nsspellchecker .lce files from the latest release on the Releases page: https://github.com/trevordevore/spell_checker/releases/
2) Install the .lce files in LiveCode: https://lessons.livecode.com/m/4071/l/1031437-how-to-install-an-extension-using-the-extension-manager
3) Open the spell_checker.livecodescript stack and `start using` it as a library.

## DLL dependencies on Windows

The `libhunspell.dll` requires that `MSVCP140.dll` and `VCRUNTIME140.dll` be installed. If your application is built with the Windows 32-bit LiveCode engine a user may not have those files in the `SysWOW64` folder.

To fix the issue install the "Microsoft Visual C++ Redistributable for Visual Studio 2015, 2017 and 2019" x86 installer available at the following url below.

https://support.microsoft.com/en-us/topic/the-latest-supported-visual-c-downloads-2647da03-1eea-4433-9aff-95f26a218cc0

If you see the error message and your app is built with the Windows 64-bit LiveCode engine then install the x64 installer. I am not aware of situations where this has occurred though.

# Additional information on dictionary files

The following web page may be helpful in understanding how the .dic and .aff files that make up a dictionary are formatted:

https://www.chromium.org/developers/how-tos/editing-the-spell-checking-dictionaries
