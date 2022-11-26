

IsTestFileChecker = {}

  function IsTestFileChecker.isTestFile(file_path)
   return file_path:match('Test%.java$') ~= nil
  end

return IsTestFileChecker
