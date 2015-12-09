quaddy = require 'quaddy'
lnglattotile = require 'lnglattotile'

module.exports = (coordinates, zoom) ->
  result = quaddy.preallocate zoom

  for i in [0...coordinates.lon.length]
    # properly wrap coodinates
    coordinates.lon[i] = (coordinates.lon[i] + 180 + 360) % 360 - 180
    # reject outliers
    continue if Math.abs(coordinates.lat[i]) > 85
    tile = lnglattotile coordinates.lon[i], coordinates.lat[i], zoom
    bin = result.assert tile[0], tile[1], tile[2]
    bin.count ?= 0
    bin.count++
    bin.indexes ?= []
    bin.indexes.push i

  result.visit zoom - 1, 0, (x, y, z) ->
    count = 0
    for node in quaddy.down x, y, z
      count += result.get(node[0], node[1], node[2])?.count ? 0
    return if count is 0
    bin = result.assert x, y, z
    bin.count = count

  # Print out a random point
  randomindex = Math.floor(Math.random() * (coordinates.lon.length - 1))
  randompoint = [
    parseFloat coordinates.lon[randomindex].toFixed 2
    parseFloat coordinates.lat[randomindex].toFixed 2
  ]
  randomtile = lnglattotile randompoint[0], randompoint[1], zoom
  console.log randomindex
  console.log randompoint
  console.log randomtile

  result