function s = readListFile(filename)
    s = textread(filename, '%s', -1, 'whitespace', '\n');
end