import QtQuick 2.0

import "./calendars"

CalendarManager {
	id: eventModel

	property var calendarManagerList: []
	property var calendarPluginMap: ({}) // Empty Map
	property var eventsData: { "items": [] }

	Component.onCompleted: {
		bindSignals(googleCalendarManager)
		bindSignals(googleTasksManager)
		bindSignals(plasmaCalendarManager)
		// bindSignals(icalManager)
		// bindSignals(debugCalendarManager)
		// bindSignals(debugGoogleCalendarManager)
	}

	//---
	function fetchingDataListener() { eventModel.asyncRequests += 1 }
	function allDataFetchedListener() { eventModel.asyncRequestsDone += 1 }
	function calendarFetchedListener(calendarId, data) {
		eventModel.setCalendarData(calendarId, data)
	}
	function eventAddedListener(calendarId, data) {
		eventModel.mergeEvents()
		eventModel.eventAdded(calendarId, data)
	}
	function eventCreatedListener(calendarId, data) {
		eventModel.eventCreated(calendarId, data)
	}
	function eventRemovedListener(calendarId, eventId, data) {
		eventModel.mergeEvents()
		eventModel.eventRemoved(calendarId, eventId, data)
	}
	function eventDeletedListener(calendarId, eventId, data) {
		eventModel.eventDeleted(calendarId, eventId, data)
	}
	function eventUpdatedListener(calendarId, eventId, data) {
		eventModel.mergeEvents()
		eventModel.eventUpdated(calendarId, eventId, data)
	}

	function bindSignals(calendarManager) {
		logger.debug('bindSignals', calendarManager)
		calendarManager.fetchingData.connect(fetchingDataListener)
		calendarManager.allDataFetched.connect(allDataFetchedListener)
		calendarManager.calendarFetched.connect(calendarFetchedListener)

		calendarManager.calendarFetched.connect(function(calendarId, data){
			eventModel.calendarPluginMap[calendarId] = calendarManager
		})

		calendarManager.eventAdded.connect(eventAddedListener)
		calendarManager.eventCreated.connect(eventCreatedListener)
		calendarManager.eventRemoved.connect(eventRemovedListener)
		calendarManager.eventDeleted.connect(eventDeletedListener)
		calendarManager.eventUpdated.connect(eventUpdatedListener)

		calendarManagerList.push(calendarManager)
	}

	function getCalendarManager(calendarId) {
		return eventModel.calendarPluginMap[calendarId]
	}

	//---
	ICalManager {
		id: icalManager
		calendarList: appletConfig.icalCalendarList.value
	}

	DebugCalendarManager { id: debugCalendarManager }
	DebugGoogleCalendarManager { id: debugGoogleCalendarManager }

	GoogleApiSession {
		id: googleApiSession
	}
	GoogleCalendarManager {
		id: googleCalendarManager
		session: googleApiSession
	}
	GoogleTasksManager {
		id: googleTasksManager
		session: googleApiSession
	}

	PlasmaCalendarManager {
		id: plasmaCalendarManager
	}

	//---
	property var deferredUpdate: Timer {
		id: deferredUpdate
		interval: 200
		onTriggered: eventModel.update()
	}
	function update() {
		fetchAll()
	}

	onFetchAllCalendars: {
		for (var i = 0; i < calendarManagerList.length; i++) {
			var calendarManager = calendarManagerList[i]
			calendarManager.fetchAll(dateMin, dateMax)
		}
	}

	onAllDataFetched: mergeEvents()

	function mergeEvents() {
		logger.debug('eventModel.mergeEvents')
		delete eventModel.eventsData
		eventModel.eventsData = { items: [] }
		for (var calendarId in eventModel.eventsByCalendar) {
			eventModel.eventsData.items = eventModel.eventsData.items.concat(eventModel.eventsByCalendar[calendarId].items)
		}
	}

	//---
	function createEvent(calendarId, date, text) {
		if (plasmoid.configuration.agenda_newevent_remember_calendar) {
			plasmoid.configuration.agenda_newevent_last_calendar_id = calendarId
		}

		var calendarManager = getCalendarManager(calendarId)
		if (calendarManager) {
			calendarManager.createEvent(calendarId, date, text)
		} else {
			logger.log('Could not createEvent. Could not find calendarManager for calendarId = ', calendarId)
		}
	}

	function deleteEvent(calendarId, eventId) {
		var calendarManager = getCalendarManager(calendarId)
		if (calendarManager) {
			calendarManager.deleteEvent(calendarId, eventId)
		} else {
			logger.log('Could not deleteEvent. Could not find calendarManager for calendarId = ', calendarId)
		}
	}

	function setEventProperty(calendarId, eventId, key, value) {
		logger.debug('eventModel.setEventProperty', calendarId, eventId, key, value)
		if (calendarId == "debug") {
			debugCalendarManager.setEventProperty(calendarId, eventId, key, value)
		} else if (true) { // Google Calendar
			googleCalendarManager.setEventProperty(calendarId, eventId, key, value)
		} else {
			logger.log('cannot edit the event property for the calendar', calendarId, eventId)
		}
	}

	function setEventProperties(calendarId, eventId, args) {
		logger.debugJSON('eventModel.setEventProperties', calendarId, eventId, args)
		if (calendarId == "debug") {
			var keys = Object.keys(args)
			for (var i = 0; i < keys.length; i++) {
				var key = keys[i]
				var value = args[key]
				debugCalendarManager.setEventProperty(calendarId, eventId, key, value)
			}
		} else if (true) { // Google Calendar
			googleCalendarManager.updateGoogleCalendarEvent(calendarId, eventId, args)
		} else {
			logger.log('cannot edit the event property for the calendar', calendarId, eventId)
		}
	}

	//--- CalendarManager
	function getCalendarList() {
		var calendarList = []
		for (var i = 0; i < calendarManagerList.length; i++) {
			var calendarManager = calendarManagerList[i]
			var list = calendarManager.getCalendarList()
			// logger.debugJSON(calendarManager.toString(), list)
			calendarList = calendarList.concat(list)
		}
		return calendarList
	}
}
