
RootFinder = {}
  function RootFinder.findRoot(dir)
    return dir:match('(.*)src')
  end

return RootFinder

