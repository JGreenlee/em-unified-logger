/*global cordova, module*/

var exec = require("cordova/exec")

var ULogger = {
    /* This is the only call to native code. For the others, we can just read
     * the database directly, which will (thoretically) reduce development
     * effort. It will also help us understand how to use one plugin as part of
     * another plugin (assuming such a thing is possible, and provide a good
     * exemplar for the usercache plugin.
     */
    LOG_TABLE: "logTable",
    KEY_ID: "ID",
    KEY_TS: "ts",
    KEY_LEVEL: "level",
    KEY_MESSAGE: "message",

    LEVEL_DEBUG: "DEBUG",
    LEVEL_INFO: "INFO",
    LEVEL_WARN: "WARN",
    LEVEL_ERROR: "ERROR",

    /*
     * If this is not done, then we may read read the table before making any
     * native calls, and on iOS, that will cause us to create a loggerDB
     * instead of copying the template.
     */
    db: function() {
        // One handle for each thread
        if (ULogger.dbHandle == null) {
            ULogger.dbHandle = window.sqlitePlugin.openDatabase({
                name: "loggerDB",
                location: 2,
                createFromLocation: 1
            });
        }
        return dbHandle;
    },

    /*
     * Arguments:
     *  - tag: module or component name, such as "usercache" or "tracking"
     *  - errorCallback: function to pass any errors while logging.
     *    The expectation is that it takes a single argument.
     */

    log: function (level, message, errorCallback) {
        exec(null, errorCallback, "UnifiedLogger", "log", [level, message]);
    },

    clearAll: function(successCallback, errorCallback) {
        exec(null, errorCallback, "UnifiedLogger", "clear", []);
    },

    /*
     * The issue here is that we are returning the log in reverse chron order,
     * so that users don't have to load the entire database in order to see
     * what's going on right now.  This means that we need to start the current
     * index at the max index.  Unfortunately, we don't know what that is until
     * we have started reading the database. This function returns the max
     * index, to be passed to the getMessagesFromIndex function.
     */
    getMaxIndex: function (successCallback, errorCallback) {
        ULogger.db().readTransaction(function(tx) {
            var maxIndexQuery = "SELECT MAX(ID) FROM "+ULogger.LOG_TABLE;
            console.log("About to execute query "+maxIndexQuery+" against "+ULogger.LOG_TABLE);
            tx.executeSql(maxIndexQuery,
                [],
                function(tx, data) {
                    if (data.rows.length == 0) {
                        errorCallback("no max index returned - are there any index values? unable to retrieve logs")
                    } else {
                        var maxIndex = data.rows.item(0)["MAX(ID)"];
                        successCallback(maxIndex);
                    }
                }, function(e, response) {
                    errorCallback(response);
                    return false;
                })
        }, function(error) {
            errorCallback(error);
        });
    },

    getMessagesFromIndex: function (startIndex, count, successCallback, errorCallback) {
        ULogger.db().readTransaction(function(tx) {
            var selQuery = "SELECT * FROM "+ULogger.LOG_TABLE+
                           " WHERE "+ULogger.KEY_ID+" < "+startIndex+
                           " ORDER BY "+ULogger.KEY_ID+" DESC LIMIT "+count;
            // Log statements in the logger don't go into the logger.
            // No infinite loop here!
            console.log("About to execute query "+selQuery+" against "+ULogger.LOG_TABLE);
            tx.executeSql(selQuery,
                [],
                function(tx, data) {
                    var resultList = [];
                    console.log("Result has "+data.rows.length+" rows");
                    for (i = 0; i < data.rows.length; i++) {
                        var currRow = data.rows.item(i);
                        currRow.fmt_time = moment.unix(currRow.ts).format("llll");
                        resultList.push(currRow);
                    }
                    successCallback(resultList);
                },
                function(e, response) {
                    errorCallback(response);
                    return false;
                });
        }, function(error) {
            errorCallback(error);
        });
    },

    ensureOpen: function() {
        if (!(ULogger.db().dbname in ULogger.db().openDBs)) {
            ULogger.log(ULogger.LEVEL_INFO, "re-opened closed database", function(error) {
                alert("Error "+error+" while opening logging database");
            });
            ULogger.db().open();
        };
    },

    getMessagesForRange: function (startTime, endTime, successCallback, errorCallback) {
    }
}

module.exports = ULogger;
