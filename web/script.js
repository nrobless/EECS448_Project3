var keepStreamsGoing;
var currentPlayer = $("input:radio[name ='player']:checked").val();
var playerTurn = "";

function getTimeString() {
    var d = new Date();
    var ret = d.getHours() + ":" + d.getMinutes() + ":" + d.getSeconds() + ":" + d.getMilliseconds();
    return ret;
}

function error(jsonData) {
    if (!jsonData.message) {
        console.log("Error: an error command needs to have a message!!!");
        return;
    }

    console.log("Error from server says: |" + jsonData.message + "|");
}

/**
 * function that updates messages based on data from the stream
 * @param jsonData
 */
function newMessage(jsonData) {
    if (!jsonData.message) {
        console.log("Error: a message command needs to have a message!!!");
        return;
    }

    if (!jsonData.player) {
        console.log("Error: a message command needs to have a player!!!");
        return;
    }

    var messageOwner = "";
    var color = "";

    if(jsonData.player === "P1") {
        messageOwner = "Player 1";
        color = "green-color";
    } else {
        messageOwner = "Player 2";
        color = "red-color";
    }

    $('#chat-messages').prepend("<div class='message " + color + "'><strong>" + messageOwner + ": </strong>" + jsonData.message + "</div>");
}

/**
 * function that updates the game and status based on jsonData from the stream
 * @param jsonData
 */
function updateGameInfo(jsonData) {

    if( jsonData["whosTurn"] )
    {
        playerTurn = jsonData["whosTurn"];
        if(playerTurn == "P1") {
            $("#playerTurn").text("Player 1");
        } else if(playerTurn == "P2") {
            $("#playerTurn").text("Player 2");
        } else {
            $("#playerTurn").text("No One");
        }
    }
    else
    {
        console.log( "Error: no whosTurn field this update!!!" );
    }

    if( jsonData["winner"] && jsonData["status"] === "gameOver" )
    {
        var theVictor = jsonData["winner"];

        if(theVictor === "P1") {
            $("#victoryMsg").text("Player 1 Wins!");
        } else if(theVictor === "P2") {
            $("#victoryMsg").text("Player 2 Wins!");
        }
    }
    else if(jsonData["status"] !== "gameOver") {
            $("#victoryMsg").text("");
    }
    else
    {
        console.log( "Error: no winner field this update!!!" );
    }

    if (jsonData["board"]) {
        var board = jsonData["board"];
        if(jsonData["status"]) {
            updateBoard(board);
        }
    }
    else {
        console.log("Did not find board!!!");
    }
    //
    console.log("got update");
    return;
}

/**
 * function that tracks the stream and executes certain functions based on what's returned by the stream
 * @param streamName
 * @param data
 */
function stream_process(streamName, data) {
    var jsonData;

    try {
        jsonData = JSON.parse(data);
    }
    catch (err) {
        console.log(streamName + " : Could not convert data to JSON : |" + data + "| : " + getTimeString());
        return;
    }

    //console.log( streamName + " : |" + data + "| : " + getTimeString() );

    if (!jsonData.name) {
        console.log("Error: command needs to have a name!!!");
        return;
    }

    if (jsonData.name == "ERROR") {
        error(jsonData);
        return;
    }
    if (jsonData.name == "newMessage") {
        newMessage(jsonData);
        return;
    }
    if (jsonData.name == "updateGameInfo") {
        updateGameInfo(jsonData);
        return;
    }
}

function stream_progress() {
    var last_index = this.j_last_index;

    var curr_index = this.responseText.length;
    if (last_index >= curr_index) return;

    var gameDataFormat = /<==(.*?)==>/;
    var curr_response = this.responseText.substring(last_index, curr_index);
    var match;

    while (match = gameDataFormat.exec(curr_response)) {
        // This is a valid data member comming back from the server, do stuff with it.
        stream_process(this.j_stream_name, match[1]);

        // The browser might have combined more than  1 response, so don't miss it, try for more.

        var step = match.index + match[0].length;
        curr_response = curr_response.substring(step);
        this.j_last_index += step;
    }
}

function stream_onreadystatechange() {
    if (this.readyState == 4 && this.status == 200) {
        console.log("Connection died OK though!!!" + " : " + getTimeString());

        if (this.j_stream_name == "stream1" || this.j_stream_name == "stream2") {
            if (keepStreamsGoing) {
                sendCommand(this.j_stream_name, getStreamData());
            }
        }
    }
    else if (this.readyState == 4 && this.status == 503) {
        console.log("Problem with game " + " : " + this.responseText + " : " + getTimeString());
    }
}

/**
 * function that accepts a command name and data to be sent to the server
 * @param stream_name is the name of the command
 * @param postData is the name of the data to be sent with the command
 */
function sendCommand(stream_name, postData) {
    var xhttp = new XMLHttpRequest();
    xhttp.open("POST", "https://people.eecs.ku.edu/~jfustos/cgi-bin/ticTacToeCommand.cgi", true);
    xhttp.j_last_index = 0;
    xhttp.j_stream_name = stream_name;
    xhttp.onprogress = stream_progress;
    xhttp.onreadystatechange = stream_onreadystatechange;
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send(postData);
}

/**
 * function that creates an object that will be used to request a gamestream for the currently selected player
 */
var getStreamData = function() {
    return JSON.stringify({"name": "getGameStream", "player": currentPlayer});
};

/**
 * function that starts a game, resets the board first and then creates a startgame object
 * that is intended to be returned in a sendCommand()
 */
var startGame = function() {
    resetBoard();
    return JSON.stringify({"name": "startGame", "player": currentPlayer});
};


/**
 * function that accepts a row and column and then encases the row and column in an object that is sent to the
 * server by way of sendCommand()
 * @param {int} row
 * @param {int} col
 */
function sendMove(row, col) {
    var sendMoveData = JSON.stringify({"name": "move", "player": currentPlayer, "row": row, "col": col});
    sendCommand("moveStream", sendMoveData);
}

/**
 * function that starts the streams for a player, each player has two streams.
 */
function startStreams() {
    keepStreamsGoing = true;
    sendCommand("stream1", getStreamData());
    sendCommand("stream2", getStreamData());
}

/**
 * function that stops the streams from continuing
 */
function stopStreams() {
    keepStreamsGoing = false;
}


//------------------------------Stuff that Haaris coded----------------------------

/**
 * Changes the currently used icon based on which player is currently selected.
 * Player1 -> Green Xs
 * Player2 -> Red Os
 * @param {string} player
 */
function changeIcon(player) {
    if (player === 'P2') {
        $(".boardPlace").css("background-image", "url('./O.svg')");
    } else {
        $(".boardPlace").css("background-image", "url('./X.svg')");
    }
}

/**
 * Function that accepts a 2d array that represents the board and changes the board in the view to reflect that board.
 * This function is called continuously throughout the game to reflect the board that is stored in the server.
 * @param {string[][]} board
 */
function updateBoard(board) {
    for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
            if(board[i][j] === 'X') {
                $("#r"+i+"c"+j).addClass('boardPlace-marked').removeClass('boardPlace').css("background-image", "url('./X.svg')");
            } else if (board[i][j] === 'O') {
                $("#r"+i+"c"+j).addClass('boardPlace-marked').removeClass('boardPlace').css("background-image", "url('./O.svg')");
            } else {
                $("#r"+i+"c"+j).addClass('boardPlace-marked').removeClass('boardPlace').css("background-image", "url('./blank.svg')");
            }
        }
    }
}

/**
 * A function that resets the board using a nested forloop and utilzing the IDs of each place on the board.
 * Places on the board are reset by removing the .boardPlace-marked class and adding .boardPlace instead.
 */
function resetBoard() {
    for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
            $("#r"+i+"c"+j).removeClass('boardPlace-marked').addClass('boardPlace');
        }
    }

    currentPlayer = $("input:radio[name ='player']:checked").val();
    changeIcon(currentPlayer);
}

/**
 * A function that sends a message to the server, the message is first converted to a readable object
 * and then the command that the server recognizes is called.
 * @param {string} message
 */
function sendMessage(message) {
    var messageObj = JSON.stringify({"name": "sendMessage", "player": currentPlayer, "message": message});
    sendCommand('message', messageObj);

}

/**
 * jQuery that checks for a click on a .boardPlace and then marks that .boardPlace by removing the .boardPlace class
 * and adding the .boardPlace-marked class
 */
$('.boardPlace').click(function (event) {
    if(currentPlayer === playerTurn) {
        $('#' + event.target.id).addClass('boardPlace-marked').removeClass('boardPlace');
    }
});

/**
 * jQuery for the radio buttons. Finds the value that's checked and changes the currentPlayer to reflect which
 * radiobutton is checked.
 */
$("input:radio[name = 'player']").click(function () {
    currentPlayer = $("input:radio[name ='player']:checked").val();
    changeIcon(currentPlayer);
});

/**
 * jQuery that implments scrolling for the #chat-messages div
 */
/* Chatbox scrolling from http://stackoverflow.com/questions/20627807/jquery-chat-box-show-first-messages-at-bottom-of-div-moving-up */
$('#chat-messages').scrollTop($('#chat-messages')[0].scrollHeight);

/**
 * jQuery that checks if the input with id "send" has something in it and that the enter button was pressed.  If so, send a message
 * to be placed in the #chat-messages div.
 */
$("#send").keypress(function(e) {
    message = $("#send").val();

    if(e.which == 13 && message != '' ) {
        sendMessage(message);
        $("#send").val('');
    }
});

