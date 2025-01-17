transport = require('./transport')
utils = require('./utils')

class XhrStreamingReceiver extends transport.ResponseReceiver
    protocol: "xhr-streaming"

    doSendFrame: (payload) ->
        return super(payload + '\n')

class XhrPollingReceiver extends XhrStreamingReceiver
    protocol: "xhr"
    max_response_size: 1


exports.app =
    xhr_options: (req, res) ->
        res.statusCode = 204    # No content
        res.setHeader('Allow-Control-Allow-Methods', 'OPTIONS, POST')
        res.setHeader('Access-Control-Max-Age', res.cache_for)
        return ''

    xhr_send: (req, res, data) ->
        if not data
            throw {
                status: 500
                message: 'Payload expected.'
            }
        try
            d = JSON.parse(data)
        catch e
            throw {
                status: 500
                message: 'Broken JSON encoding.'
            }

        if not d or d.__proto__.constructor isnt Array
            throw {
                status: 500
                message: 'Payload expected.'
            }
        jsonp = transport.Session.bySessionId(req.session)
        if not jsonp
            throw {status: 404}
        for message in d
            jsonp.didMessage(message)

        # FF assumes that the response is XML.
        res.setHeader('Content-Type', 'text/plain; charset=UTF-8')
        res.writeHead(204)
        res.end()
        return true

    xhr_cors: (req, res, content) ->
        origin = req.headers['origin'] or '*'
        res.setHeader('Access-Control-Allow-Origin', origin)
        headers = req.headers['access-control-request-headers']
        if headers
            res.setHeader('Access-Control-Allow-Headers', headers)
        res.setHeader('Access-Control-Allow-Credentials', 'true')
        return content

    xhr_poll: (req, res, _, next_filter) ->
        res.setHeader('Content-Type', 'application/javascript; charset=UTF-8')
        res.writeHead(200)

        transport.register(req, @, new XhrPollingReceiver(res, @options))
        return true

    xhr_streaming: (req, res, _, next_filter) ->
        res.setHeader('Content-Type', 'application/javascript; charset=UTF-8')
        res.writeHead(200)

        # IE requires 2KB prefix:
        #  http://blogs.msdn.com/b/ieinternals/archive/2010/04/06/comet-streaming-in-internet-explorer-with-xmlhttprequest-and-xdomainrequest.aspx
        res.write(Array(2049).join('h') + '\n')

        transport.register(req, @, new XhrStreamingReceiver(res, @options) )
        return true
