gulp = require "gulp"
jshint = require "gulp-jshint"
nodemon = require "gulp-nodemon"
coffee = require "gulp-coffee"
gutil = require "gulp-util"
concat = require "gulp-concat"

buildScripts = [
    "./bower_components/jquery/dist/jquery.min.js"
    "./bower_components/lodash/lodash.min.js"
    "./bower_components/tock/tock.min.js"
    "./bower_components/jquery-mousewheel/jquery.mousewheel.min.js"
    "./dist/footprint.js"
]

gulp.task "lint", ->
    gulp.src "."
        .pipe jshint()
        .pipe jshint.reporter "jshint-stylish"

gulp.task "coffee", ->
    gulp.src "./src/*.coffee"
        .pipe coffee bare: true
        .on "error", ->
            console.log err?.toString()
            @emit "end"
        .pipe gulp.dest "./dist/"

gulp.task "build", ->
    gulp.src buildScripts
        .pipe concat "full.footprint.js"
        .pipe gulp.dest "./dist/"

gulp.task "watch", ->
    gulp.watch "./src/*.coffee", ["coffee", "build"]

gulp.task "server", ->
    nodemon
        script: "app.coffee"
        ext: "coffee"
        env: "NODE_ENV": "development"
    .on "change", ["lint"]

gulp.task "default", ["server", "watch"]
