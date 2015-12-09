whakaruru = require 'whakaruru-watch/verbose'
whakaruru '**/*.js', ->
  express = require 'express'
  mutunga = require 'http-mutunga'
  fs = require 'fs'
  tiletolnglat = require 'tiletolnglat'
  quadify = require './quadify'
  async = require 'odo-async'
  filesize = require 'filesize'

  app = express()
  app.disable 'x-powered-by'  # Remove header
  compression = require 'compression'
  app.use compression()  # Enable gzip

  datasets = fs.readFileSync './datasets.json'
  datasets = JSON.parse datasets

  console.log "Loading #{Object.keys(datasets).length} datasets from HD"
  heap = process.memoryUsage().heapUsed
  tasks = []
  for name, dataset of datasets
    do (name, dataset) ->
      tasks.push (cb) ->
        fs.readFile dataset.file, (err, points) ->
          points = JSON.parse points
          dataset.points = points
          cb()
  async.parallel tasks, ->
    heap = process.memoryUsage().heapUsed - heap
    console.log "#{filesize heap} for #{Object.keys(datasets).length} raw datasets"
    for name, dataset of datasets
      console.log "Quadding #{name}"
      dataset.tree = quadify dataset.points, dataset.zoom
    heap = process.memoryUsage().heapUsed - heap
    console.log "#{filesize heap} for #{Object.keys(datasets).length} dataset quadtrees"

    app.get '/', (req, res) ->
      res.send datasets: Object.keys(datasets).map (name) ->
        dataset = datasets[name]
        name: name
        points: dataset.points.lon.length
        zoom: dataset.zoom
        url: "/#{name}/{z}/{x}/{y}.json"

    app.get '/:dataset/:z/:x/:y.json', (req, res) ->
      name = req.params.dataset
      if !datasets[name]?
        res.status 404
        res.send message: "#{name} is not a valid dateset"
        return
      dataset = datasets[name]
      x = parseInt req.params.x
      y = parseInt req.params.y
      z = parseInt req.params.z
      node = dataset.tree.get x, y, z
      res.send
        type: 'FeatureCollection'
        features: [
          {
            id: 'count'
            type: 'Feature'
            geometry:
              type: 'Point'
              coordinates: tiletolnglat x + 0.5, y + 0.5, z
            properties:
              count: node?.count ? 0
          }
          {
            id: 'points'
            type: 'Feature'
            geometry:
              type: 'MultiPoint'
              coordinates: if node?.indexes?
                  node.indexes.map (i) ->
                    [
                      parseFloat dataset.points.lon[i].toFixed 2
                      parseFloat dataset.points.lat[i].toFixed 2
                    ]
                else
                  []
          }
        ]

    server = mutunga(app).listen 8080, ->
      process.on 'SIGTERM', ->
        console.log "#{process.pid} Ōhākī"
        server.close -> process.exit 0
