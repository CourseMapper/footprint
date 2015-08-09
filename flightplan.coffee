plan = require "flightplan"

plan.target "stage",
    host: "sabov.me"
    username: "root"
    agent: process.env.SSH_AUTH_SOCK
    branch: "master"

plan.remote (remote) ->
    remote.log "****====== Start remote deploy ======****"

    remote.with "cd /var/www/footprint", ->

        remote.log "update source"
        remote.exec "git checkout #{remote.runtime.branch}"
        remote.exec "git pull"

        remote.log "Install dependencies"

        remote.exec "npm install"
        remote.exec "bower i --alow-root"

        remote.log "build app"
        remote.exec "gulp build"

        remote.log "reload app"
        remote.exec "pm2 restart all"
