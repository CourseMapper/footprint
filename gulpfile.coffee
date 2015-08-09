gulp = require "gulp"
jshint = require "gulp-jshint"
nodemon = require "gulp-nodemon"
less = require "require-less"
rename = require "gulp-rename"
browserify = require "gulp-browserify"
uglify = require "gulp-uglify"
svg = require "svg-browserify"

gulp.task "build", ->
    gulp.src "./src/*.coffee", read: false
        .pipe browserify
            transform: ["coffeeify", "node-lessify", "jadeify", svg]
            extensions: [".coffee"]
        #.pipe uglify()
        .pipe rename "footprint.js"
        .pipe gulp.dest "./dist/"

gulp.task "lint", ->
    gulp.src "."
        .pipe jshint()
        .pipe jshint.reporter "jshint-stylish"

gulp.task "watch", ->
    gulp.watch "./src/*", ["build"]

gulp.task "server", ->
    nodemon
        script: "app.coffee"
        ext: "coffee"
        env: "NODE_ENV": "development"
    .on "change", ["lint"]

gulp.task "default", ["server", "watch"]
