var keepStreamsGoing;
var mydata;
var gameActive = false;
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

function newMessage(jsonData) {
    if (!jsonData.message) {
        console.log("Error: a message command needs to have a message!!!");
        return;
    }

    if (!jsonData.player) {
        console.log("Error: a message command needs to have a player!!!");
        return;
    }

    console.log("MESSAGE from |" + jsonData.player + "| says |" + jsonData.message + "|");
}

function updateGameInfo(jsonData) {
    // mydata = jsonData;
    //
    // if( jsonData["status"] )
    // {
    //     document.getElementById("gameStatusBox").value = "" + jsonData["status"];
    // }
    // else
    // {
    //     console.log( "Error: no status field this update!!!" );
    // }
    //
    if( jsonData["whosTurn"] )
    {
        playerTurn = jsonData["whosTurn"];
    }
    else
    {
        console.log( "Error: no whosTurn field this update!!!" );
    }

    // if( jsonData["status"] )
    // {
    //     if(jsonData["status"] === "Waiting") {
    //         gameActive = true;
    //     } else {
    //         gameActive = false;
    //     }
    // }
    // else
    // {
    //     console.log( "Error: no winner field this update!!!" );
    // }
    //
    // if( jsonData["player"] && jsonData["player"][0] && jsonData["player"][0]["name"] && jsonData["player"][0]["status"])
    // {
    //     document.getElementById("P1").value = 	"name: "    + jsonData["player"][0]["name"]   +
    //         " wins: "   + jsonData["player"][0]["wins"]   +
    //         " losses: " + jsonData["player"][0]["losses"] +
    //         " ties: "   + jsonData["player"][0]["ties"]   +
    //         " status: " + jsonData["player"][0]["status"];
    // }
    // else
    // {
    //     console.log( "Error: Player 1 is messed up!!!" );
    // }
    //
    // if( jsonData["player"] && jsonData["player"][1] && jsonData["player"][1]["name"] && jsonData["player"][1]["status"])
    // {
    //     document.getElementById("P2").value = 	"name: "    + jsonData["player"][1]["name"]   +
    //         " wins: "   + jsonData["player"][1]["wins"]   +
    //         " losses: " + jsonData["player"][1]["losses"] +
    //         " ties: "   + jsonData["player"][1]["ties"]   +
    //         " status: " + jsonData["player"][1]["status"];
    // }
    // else
    // {
    //     console.log( "Error: Player 2 is messed up!!!" );
    // }
    //
    if (jsonData["board"]) {
        var board = jsonData["board"];
        if(jsonData["status"]) {
            updateBoard(board);
        }
        // document.getElementById("r0c0").value = "" + jsonData["board"][0][0];
        // document.getElementById("r0c1").value = "" + jsonData["board"][0][1];
        // document.getElementById("r0c2").value = "" + jsonData["board"][0][2];
        // document.getElementById("r1c0").value = "" + jsonData["board"][1][0];
        // document.getElementById("r1c1").value = "" + jsonData["board"][1][1];
        // document.getElementById("r1c2").value = "" + jsonData["board"][1][2];
        // document.getElementById("r2c0").value = "" + jsonData["board"][2][0];
        // document.getElementById("r2c1").value = "" + jsonData["board"][2][1];
        // document.getElementById("r2c2").value = "" + jsonData["board"][2][2];
    }
    else {
        console.log("Did not find board!!!");
    }
    //
    console.log("got update");
    return;
}

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

function sendCommand(stream_name, postData) {
    var xhttp = new XMLHttpRequest();
    xhttp.open("POST", "https://people.eecs.ku.edu/~jfustos/cgi-bin/testSocket.cgi", true);
    xhttp.j_last_index = 0;
    xhttp.j_stream_name = stream_name;
    xhttp.onprogress = stream_progress;
    xhttp.onreadystatechange = stream_onreadystatechange;
    xhttp.setRequestHeader("Content-type", "application/json");
    xhttp.send(postData);
}

var getStreamData = function() {
    return JSON.stringify({"name": "getGameStream", "player": currentPlayer});
};

var startGame = function() {
    resetBoard();
    return JSON.stringify({"name": "startGame", "player": currentPlayer});
};

var sendMessageData1 = function() {
    JSON.stringify({"name": "sendMessage", "player": currentPlayer, "message": "I love egg plant."});
};

var sendMessageData2 = function() {
    return JSON.stringify({"name": "sendMessage", "player": currentPlayer, "message": "I can't stand MIKEY!!!!!"});
};

function sendMove(row, col) {
    var sendMoveData = JSON.stringify({"name": "move", "player": currentPlayer, "row": row, "col": col});
    sendCommand("moveStream", sendMoveData);
}

function startStreams() {
    keepStreamsGoing = true;
    sendCommand("stream1", getStreamData());
    sendCommand("stream2", getStreamData());
}

function stopStreams() {
    keepStreamsGoing = false;
}

function main() {

}

//------------------------------Stuff that Haaris coded----------------------------

function changeIcon(player) {
    if (player === 'P2') {
        $(".boardPlace").css("background-image", "url('./O.svg')");
    } else {
        $(".boardPlace").css("background-image", "url('./X.svg')");
    }
}

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

function resetBoard() {
    for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
            $("#r"+i+"c"+j).removeClass('boardPlace-marked').addClass('boardPlace');
        }
    }

    currentPlayer = $("input:radio[name ='player']:checked").val();
    changeIcon(currentPlayer);
}
// function setGameStatus(boolVar) {
//     gameActive = boolVar;
// }

$('.boardPlace').click(function (event) {
    if(currentPlayer === playerTurn) {
        console.log(event.target.id);
        console.log(currentPlayer);
        $('#' + event.target.id).addClass('boardPlace-marked').removeClass('boardPlace');
    }
});

$("input:radio[name = 'player']").click(function () {
    currentPlayer = $("input:radio[name ='player']:checked").val();
    changeIcon(currentPlayer);
});

console.log(currentPlayer);

/* To do
On gameOver: Make sure to refresh screen

 */