http = require('http');  https = require('https'); url = require('url'); util = require('util')
program = require('commander'); _ = require('underscore')

process.on 'uncaughtException',  (err) ->
	console.error("uncaughtException: #{err.message}")
	console.error(err.stack)
	process.exit(1)

program
	.version('0.0.6')
	.usage('[options] <url e.g "http://www.google.com/index.html">')
	.option('-c, --concurrency <n>',	'Number of concurrent clients (default: 1)', parseInt, 1)
	.option('-r, --ramp <n>',					'Time to ramp up clients (default: 1s)', parseInt, 1)
	.option('-t, --think <n>',				'Think time (default: 1s)', parseInt, 1)
	.option('-d, --duration <n>',			'Test duration excluding ramp-up time and ramp-down times (default: 60s)', parseInt, 60)
	.option('-T, --timeout <n>',			'Request timeout (default: 60s)', parseInt, 60)
	.option('-p, --partials <n>',			'Print partial results every n seconds (0 to disable  - this is the default)', parseInt, 0)
	.option('-v, --verbose',					'Verbose logs (for debugging)')
	.parse(process.argv)

verbose = ->
	if program.verbose
		console.log.apply this, arguments

program.url = url.parse(program.args.pop())
if program.verbose
 console.log(util.format("Options:\n%s\n\n",util.inspect(program)))

class Benchmark
	
	constructor: (@params)->
		@_results			=
			errors: []
			successes: []
		@_clients			= []
		@_pending			= 0
		@_status			= 'started'
		@_partials		= null
		for i in [1..@params.concurrency]
			setTimeout @createClient, Math.round(i*@params.ramp*1000/@params.concurrency)
		if @params.partials > 0
			@_partials = setInterval @print, @params.partials * 1000
		process.on("exit", @print)
		process.on('SIGINT', (->process.exit(1)))
		
	createClient: =>
		try
			@_clients.push(new BenchClient(@params, @))
			if @_clients.length is @params.concurrency
				@_status = 'wip'
				setTimeout @stop, @params.duration * 1000
		catch boo
			console.error(boo)
	stop:=>
		@_status = 'stopped'
		clearInterval(@_partials)
		if program.verbose
			console.log('stopped')
		#if @_pending is 0
		#	process.exit(0)
	getStatus: =>
		return @_status
	addSuccess: (success)=>
		verbose "#{@_pending} pending requests (1 added), #{success.elapsed}ms elapsed"
		@_results.successes.push(success)
	addError: (error)=>
		err = _.find @_results.errors, (e)->_.isEqual(e.instance, error)
		if err
			err.count += 1
		else
			@_results.errors.push({instance: error, count: 1})

	addPending: (client)=>
		@_pending += 1
		verbose "#{@_pending} pending requests (1 added)"
	removePending: (client)=>
		@_pending -= 1
		verbose "#{@_pending} pending requests (1 removed)"
		#if @_status is 'stopped' and @_pending is 0
		#	process.exit(0)
	print: =>
		successes = _.sortBy @_results.successes, (s)-> s.elapsed
		errorCount = _.reduce @_results.errors, ( (m, e)-> m += e.count ), 0
		totalTime = _.reduce successes, ( (m, r)-> m+r.elapsed ), 0
		console.log("Requests: #{errorCount+successes.length}")
		console.log("Errors: #{errorCount}")
		for e in @_results.errors
			console.log("\t- #{e.count} occurence(s) of #{util.format('%j',e.instance)}")
			
		if successes.length > 0
			console.log("Average Time: #{Math.round(totalTime/successes.length)}ms")
			console.log("95 percentile: #{successes[Math.floor(successes.length*0.95)].elapsed}ms")
			console.log("90 percentile: #{successes[Math.floor(successes.length*0.90)].elapsed}ms")
			console.log("80 percentile: #{successes[Math.floor(successes.length*0.80)].elapsed}ms")
			console.log("70 percentile: #{successes[Math.floor(successes.length*0.70)].elapsed}ms")
			console.log("60 percentile: #{successes[Math.floor(successes.length*0.60)].elapsed}ms")
		console.log("*********************************\n\n")
	printAndExit: =>
		@print()
		process.exit(0)
		
class BenchClient
	
	constructor: (options, controller)->
		@_reqOptions = 
				hostname: options.url.hostname
				port: options.url.port
				path: options.url.path
				agent: false
				method: 'GET'
		@_options =
			protocol: if options.url.protocol is 'https:' then https else http
			think: options.think * 1000
			timeout: options.timeout * 1000
		@_controller = controller
		@sendRequest()


	sendRequest: =>
		startedTime = Date.now()
		verbose "Sending request %s", util.inspect(@_reqOptions)

		req = @_options.protocol.request @_reqOptions, (res)=>
			verbose "http status: %s", res.statusCode
			res.on 'error', @handleError
			res.on 'data', (->) # 'From the Nodejs docs: the end event will not fire unless the data is completely consumed. '
			res.on 'end', =>
				elapsed = Date.now()-startedTime
				verbose "http v #{res.httpVersion}, duration #{elapsed}ms"
				clearTimeout(timeout)
				if res.statusCode isnt 200
					@handleError(new Error("Received http code #{res.statusCode}"))
				else
					@_controller.addSuccess({elapsed: elapsed})
					@_controller.removePending(@)
				setTimeout @scheduleRequest, @_options.think

		req.on 'error', @handleError
		
		abortRequest = =>
			clearTimeout(timeout)
			req.abort()
			@handleError(new Error('timeout'))
			setTimeout @scheduleRequest, @_options.think
		timeout = setTimeout abortRequest, @_options.timeout
		req.on 'error', @handleError
		req.end()
		@_controller.addPending(@)
	

	scheduleRequest: =>
		if @_controller.getStatus() isnt 'stopped'
			@sendRequest()

	handleError: (err) =>
		verbose err.message
		@_controller.removePending(@)
		@_controller.addError(err)
		
			
benchmark = new Benchmark(program)

###
console.log 'sending mock request'

params = 
	method: 'GET'
	hostname: 'dev.swishly.com'
	path: '/proxy_are_you_here'
	port: null
	agent: false
req = http.get params, (res)->
	console.log("Got response: " + res.statusCode)
	res.on 'data', ->
		console.log 'data received'
	res.on 'end', ->
		console.log 'response received'
	res.on 'error', (err)->
		console.log 'response error'
req.on 'error', (err)->
	console.log "Request error: #{err.message}"

###


