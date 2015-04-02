gulp = require "gulp"
jshint = require "gulp-jshint"
nodemon = require "gulp-nodemon"
coffee = require "gulp-coffee"
gutil = require "gulp-util"

gulp.task "lint", ->
    gulp.src "."
        .pipe jshint()
        .pipe jshint.reporter "jshint-stylish"

gulp.task "coffee", ->
    gulp.src "./src/*.coffee"
        .pipe coffee bare: true
        .on "error", ->
            console.log err.toString()
            @emit "end"
        .pipe gulp.dest "./dist/"

gulp.task "watch", ->
    gulp.watch "./src/*.coffee", ["coffee"]

gulp.task "server", ->
    nodemon
        script: "app.coffee"
        ext: "coffee"
        env: "NODE_ENV": "development"
    .on "change", ["lint"]

gulp.task "default", ["server", "watch"]
