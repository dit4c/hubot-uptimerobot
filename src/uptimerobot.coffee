# Description
#   A hubot script to list/add monitors for the Uptime Robot service.
#
# Configuration:
#   HUBOT_UPTIMEROBOT_APIKEY
#   HUBOT_UPTIMEROBOT_CONTACT_ID (optional)
#
# Commands:
#   hubot uptime <filter> - Returns uptime for sites.
#   hubot uptime check <http://example.com> [as <friendlyname>]- Adds a new uptime check.
#
# Author:
#   patcon@myplanetdigital

UptimeRobot = require 'uptime-robot'
apiKey = process.env.HUBOT_UPTIMEROBOT_APIKEY
alertContactId = process.env.HUBOT_UPTIMEROBOT_CONTACT_ID

module.exports = (robot) ->

  REGEX = ///
    uptime
    (       # 1)
      \s+   #    whitespace
      (.*)  # 2) filter
    )?
  ///i
  robot.respond REGEX, (msg) ->
    uptimeRobot = new UptimeRobot apiKey

    filter = msg.match[2]
    data = {}
    statusMap = ['paused', 'not checked yet', 'up', 'seems down', 'down']

    uptimeRobot.getMonitors data, (err, res) ->
      throw err if err

      monitors = res

      if filter
        query = require 'array-query'
        monitors = query('friendlyname')
          .regex(new RegExp filter, 'i')
          .on res

      monitors.forEach (monitor) ->
        name   = monitor.friendlyname
        url    = monitor.url
        uptime = monitor.alltimeuptimeratio
        status = statusMap[monitor.status]
        msg.send "#{status.toUpperCase()} <- #{url} (#{uptime}% uptime)"

  # available params:
  #   monitorID monitorURL monitorFriendlyName alertType alertDetails monitorAlertContacts
  robot.router.get '/hubot/uptimerobot', (req, res) ->
    statusMap = 1: 'down', 2: 'up'

    name = req.param 'monitorFriendlyName'
    status = alertTypeMap[req.param 'alertType']
    detail = req.param 'alertDetails'
    url = req.param 'monitorURL'

    return unless robot.auth?
    robot.auth.usersWithRole('admin').forEach (name) ->
      user = robot.brain.userForName name
      envelope = room: user.room, user: {type: 'chat'}
      robot.send envelope, "The #{name} is #{status.toUpperCase()}! #{detail} #{url}"

  robot.respond /uptime check (\S+)( as (.*))?$/i, (msg) ->
    url = require('url').parse(msg.match[1])
    friendlyName = msg.match[3] or url.href

    # Check that url format is correct.
    monitorUrl = url.href if url.protocol

    # Create monitor
    msg.http("http://api.uptimerobot.com/newMonitor").query(
      apiKey: apiKey
      monitorFriendlyName: friendlyName
      monitorURL: monitorUrl
      monitorType: 1
      format: "json"
      noJsonCallback: 1
      monitorAlertContacts: [alertContactId]
    ).get() (err, res, body) ->
      response = JSON.parse body

      if response.stat is "ok"
        msg.send "done"

      if response.stat is "fail"
        msg.send "#{response.message}"
