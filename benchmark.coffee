http = require('http');  https = require('https'); url = require('url'); util = require('util')
program = require('commander'); _ = require('underscore')

process.on 'uncaughtException',  (err) ->
	console.error("uncaughtException")
	console.error(err)
	process.exit(1)

program
	.version('0.0.1')
	.usage('[options] <url e.g "http://www.google.com/index.html">')
	.option('-c, --concurrency <n>', 'Number of concurrent clients (default: 1)', parseInt, 1)
	.option('-r, --ramp <n>', 'Time to ramp up clients (default: 1s)', parseInt, 1)
	.option('-t, --think <n>', 'Think time (default: 1s)', parseInt, 1)
	.option('-T, --timeout <n>', 'Request timeout (default: 60s)', parseInt, 60)
	.option('-d, --duration <n>', 'Test duration excluding ramp-up time and ramp-down times (default: 60s)', parseInt, 60)
	.parse(process.argv)

program.url = url.parse(program.args.pop())

#console.log(util.format("%j",program))

class Benchmark

	_clients = []
	_status = null
	_pending = 0
	_results = {errors: [], successes: []}
	constructor: (@params)->
			
		_status = 'started'
		for i in [1..@params.concurrency]
			setTimeout @createClient, Math.round(i*@params.ramp*1000/@params.concurrency)
		
	createClient: =>
		try
			_clients.push(new BenchClient(@params, @))
			if _clients.length is @params.concurrency
				_status = 'wip'
				setTimeout @stop, @params.duration * 1000
		catch boo
			console.error(boo)
	stop:=>
		_status = 'stopped'
		#console.log('stopped')
		if _pending is 0
			@printAndExit()
	getStatus: =>
		return _status
	addSuccess: (success)=>
		#console.log("#{_pending} pending requests (1 added), #{success.elapsed}ms elapsed")
		_results.successes.push(success)
	addError: (error)=>
		err = _.find _results.errors, (e)->_.isEqual(e.instance, error)
		if err
			err.count += 1
		else
			_results.errors.push({instance: error, count: 1})

	addPending: (client)=>
		_pending += 1
		#console.log("#{_pending} pending requests (1 added)")
	removePending: (client)=>
		_pending -= 1
		#console.log("#{_pending} pending requests (1 removed)")
		if _status is 'stopped' and _pending is 0
			@printAndExit()
	printAndExit: =>
		successes = _.sortBy _results.successes, (s)-> s.elapsed
		errorCount = _.reduce _results.errors, ( (m, e)-> m += e.count ), 0
		totalTime = _.reduce successes, ( (m, r)-> m+r.elapsed ), 0
		console.log("Requests: #{errorCount+successes.length}")
		console.log("Errors: #{errorCount}")
		for e in _results.errors
			console.log("\t- #{e.count} occurence(s) of #{util.format('%j',e.instance)}")
			
		if successes.length > 0
			console.log("Average Time: #{Math.round(totalTime/successes.length)}ms")
			console.log("95 percentile: #{successes[Math.round(successes.length*0.95)].elapsed}ms")
			console.log("90 percentile: #{successes[Math.round(successes.length*0.90)].elapsed}ms")
			console.log("80 percentile: #{successes[Math.round(successes.length*0.80)].elapsed}ms")
			console.log("70 percentile: #{successes[Math.round(successes.length*0.70)].elapsed}ms")
			console.log("60 percentile: #{successes[Math.round(successes.length*0.60)].elapsed}ms")
		process.exit(0)
		
class BenchClient
	_options = null
	_reqOptions = null
	_controller = null
	
	constructor: (options, controller)->
		_reqOptions = 
				hostname: options.url.hostname
				port: options.url.port
				path: options.url.path
				agent: false
				method: 'GET'
		_options =
			protocol: if options.url.protocol is 'https' then https else http
			think: options.think * 1000
			timeout: options.timeout * 1000
		_controller = controller
		@sendRequest()


	sendRequest: =>
		startedTime = Date.now()
		req = _options.protocol.request _reqOptions, (res)=>
			res.on 'end', =>
				elapsed = Date.now()-startedTime
				#console.log("elapsed is #{Date.now()}-#{@_startedTime} = #{elapsed}ms" )
				#console.log("http v #{res.httpVersion}")
				clearTimeout(timeout)
				if res.statusCode isnt 200
					@handleError(res)
				else
					_controller.addSuccess({elapsed: elapsed})
					_controller.removePending(@)
				setTimeout @scheduleRequest, _options.think
		abortRequest = =>
			clearTimeout(timeout)
			req.abort()
			@handleError('timeout')
			setTimeout @scheduleRequest, _options.think
		timeout = setTimeout abortRequest, _options.timeout
		req.on 'error', (err)=> @handleError
		req.end()
		_controller.addPending(@)
	

	scheduleRequest: =>
		if _controller.getStatus() isnt 'stopped'
			@sendRequest()

	handleError: (err) =>
		#console.log(err)
		_controller.removePending(@)
		_controller.addError(err)
		
			
benchmark = new Benchmark(program)


