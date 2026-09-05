import QtQuick

Canvas {
    id: icon
    property string name: "plus"
    property color ink: "#a0a8a4"
    implicitWidth: 20
    implicitHeight: 20
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onPaint: {
        let c = getContext("2d"); c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.65;
        c.lineCap = "round"; c.lineJoin = "round";
        function line(points) { c.beginPath(); c.moveTo(points[0][0],points[0][1]); for(let i=1;i<points.length;i++) c.lineTo(points[i][0],points[i][1]); c.stroke(); }
        function rect(x,y,w,h) { c.strokeRect(x,y,w,h); }
        function circle(x,y,r) { c.beginPath(); c.arc(x,y,r,0,Math.PI*2); c.stroke(); }
        switch(name) {
        case "plus": line([[12,5],[12,19]]);line([[5,12],[19,12]]);break;
        case "search": circle(10.5,10.5,6);line([[15,15],[20,20]]);break;
        case "chat": line([[5,4],[19,4],[20,5],[20,16],[19,17],[10,17],[5,21],[5,17],[3,17],[3,5],[5,4]]);break;
        case "desktop": rect(3,4,18,13);line([[8,21],[16,21]]);line([[12,17],[12,21]]);break;
        case "arrow": line([[12,19],[12,5]]);line([[6,11],[12,5],[18,11]]);break;
        case "chevron": line([[9,5],[16,12],[9,19]]);break;
        case "down": line([[7,9],[12,14],[17,9]]);break;
        case "check": line([[5,12],[10,17],[20,6]]);break;
        case "close": line([[6,6],[18,18]]);line([[18,6],[6,18]]);break;
        case "stop": c.fillRect(7,7,10,10);break;
        case "copy": rect(8,8,12,13);line([[15,5],[15,3],[3,3],[3,15],[5,15]]);break;
        case "folder": line([[3,6],[9,6],[11,8],[21,8],[21,20],[3,20],[3,6]]);break;
        case "code": line([[8,6],[3,12],[8,18]]);line([[16,6],[21,12],[16,18]]);line([[14,3],[10,21]]);break;
        case "paint": line([[14,4],[20,10],[11,19],[5,19],[5,13],[14,4]]);line([[11,7],[17,13]]);line([[3,22],[10,22]]);break;
        case "bolt": line([[13,2],[5,13],[11,13],[10,22],[19,10],[13,10],[13,2]]);break;
        case "sliders": line([[4,6],[9,6]]);line([[15,6],[20,6]]);circle(12,6,3);line([[4,18],[13,18]]);line([[19,18],[20,18]]);circle(16,18,3);break;
        case "edit": line([[4,20],[8,19],[19,8],[15,4],[4,15],[4,20]]);line([[13,6],[17,10]]);line([[4,20],[10,20]]);break;
        case "download": line([[12,3],[12,15]]);line([[7,10],[12,15],[17,10]]);line([[4,16],[4,21],[20,21],[20,16]]);break;
        case "trash": line([[4,6],[20,6]]);line([[9,6],[9,3],[15,3],[15,6]]);line([[6,6],[7,21],[17,21],[18,6]]);line([[10,10],[10,17]]);line([[14,10],[14,17]]);break;
        case "shield": line([[12,3],[20,6],[19,15],[16,19],[12,22],[8,19],[5,15],[4,6],[12,3]]);line([[8,12],[11,15],[16,9]]);break;
        case "cursor": line([[5,3],[20,13],[13,14],[10,21],[5,3]]);break;
        case "panel": rect(3,4,18,16);line([[15,4],[15,20]]);break;
        case "sun": circle(12,12,4);for(let i=0;i<8;i++){let a=i*Math.PI/4;line([[12+7*Math.cos(a),12+7*Math.sin(a)],[12+10*Math.cos(a),12+10*Math.sin(a)]]);}break;
        default: circle(12,12,7);
        }
    }
}
