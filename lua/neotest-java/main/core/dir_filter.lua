
DirFilter = {}

  function DirFilter:filter_dir(name, rel_path, root)
    print('name: ' .. name)
    print('rel_path: ' .. rel_path)
    print('root: ' .. root)
    print(rel_path:match('src/test/java'))
    return rel_path:match('src/test/java') ~= nil
  end

return DirFilter

