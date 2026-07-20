import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: root
    objectName: "MainWindow"
    visible: true
    width: 480
    height: 720
    title: "veriCue Touch Demo"
    color: "#0a0a0f"

    property int tapCount: 0
    property int swipeCount: 0
    property real currentScale: 1.0
    property real currentRotation: 0.0

    header: ToolBar {
        objectName: "toolbar"
        background: Rectangle { color: "#16213e" }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8

            Label {
                objectName: "appTitle"
                text: "Touch Demo"
                font.pixelSize: 18
                font.bold: true
                color: "#e4e4ed"
            }

            Item { Layout.fillWidth: true }

            Button {
                objectName: "resetButton"
                text: "Reset"
                contentItem: Text {
                    text: parent.text
                    color: "#818cf8"
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 8
                    color: "transparent"
                    border.color: "#818cf8"
                    border.width: 1
                }
                onClicked: {
                    root.tapCount = 0
                    root.swipeCount = 0
                    root.currentScale = 1.0
                    root.currentRotation = 0.0
                    statusLabel.text = "Reset"
                    pinchImage.scale = 1.0
                    pinchImage.rotation = 0
                    flickList.contentY = 0
                }
            }
        }
    }

    ColumnLayout {
        objectName: "mainLayout"
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── Status Bar ──
        Rectangle {
            objectName: "statusCard"
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 12
            color: "#12121a"
            border.color: "#2a2a3a"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Column {
                    Label {
                        text: tapCount.toString()
                        font.pixelSize: 24
                        font.bold: true
                        color: "#34d399"
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                    Label { text: "Taps"; font.pixelSize: 11; color: "#8888a0"; horizontalAlignment: Text.AlignHCenter; width: parent.width }
                }
                Column {
                    Label {
                        text: swipeCount.toString()
                        font.pixelSize: 24
                        font.bold: true
                        color: "#818cf8"
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                    Label { text: "Swipes"; font.pixelSize: 11; color: "#8888a0"; horizontalAlignment: Text.AlignHCenter; width: parent.width }
                }
                Column {
                    Label {
                        objectName: "scaleLabel"
                        text: currentScale.toFixed(2) + "x"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#22d3ee"
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                    Label { text: "Scale"; font.pixelSize: 11; color: "#8888a0"; horizontalAlignment: Text.AlignHCenter; width: parent.width }
                }
                Column {
                    Label {
                        objectName: "rotationLabel"
                        text: Math.round(currentRotation) + "°"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#fbbf24"
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                    Label { text: "Rotation"; font.pixelSize: 11; color: "#8888a0"; horizontalAlignment: Text.AlignHCenter; width: parent.width }
                }
            }
        }

        // ── Tap Zone ──
        Rectangle {
            objectName: "tapZone"
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: 12
            color: tapArea.pressed ? "#1a2a1a" : "#12121a"
            border.color: tapArea.pressed ? "#34d399" : "#2a2a3a"
            border.width: tapArea.pressed ? 2 : 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Column {
                anchors.centerIn: parent
                spacing: 4

                Label {
                    text: "TAP HERE"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#e4e4ed"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Label {
                    objectName: "tapLabel"
                    text: tapCount === 0 ? "Touch to tap" : "Tapped " + tapCount + " times"
                    font.pixelSize: 13
                    color: "#8888a0"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Label {
                    id: lastTapPosition
                    objectName: "lastTapPosition"
                    text: ""
                    font.pixelSize: 11
                    color: "#555566"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MultiPointTouchArea {
                id: tapArea
                objectName: "tapTouchArea"
                anchors.fill: parent
                minimumTouchPoints: 1
                maximumTouchPoints: 1

                touchPoints: [
                    TouchPoint { id: tp1 }
                ]

                onPressed: {
                    root.tapCount++
                    lastTapPosition.text = "at (" + Math.round(tp1.x) + ", " + Math.round(tp1.y) + ")"
                    statusLabel.text = "Tap #" + root.tapCount
                }
            }
        }

        // ── Swipeable List ──
        Rectangle {
            objectName: "swipeCard"
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 12
            color: "#12121a"
            border.color: "#2a2a3a"
            clip: true

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 4

                Label {
                    text: "SWIPE LIST"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#e4e4ed"
                }
                Label {
                    id: swipeLabel
                    objectName: "swipeLabel"
                    text: "Swipe up/down to scroll"
                    font.pixelSize: 11
                    color: "#8888a0"
                }
            }

            Flickable {
                id: flickList
                objectName: "flickableList"
                anchors.fill: parent
                anchors.topMargin: 44
                anchors.margins: 8
                contentHeight: flickColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick

                onFlickStarted: {
                    root.swipeCount++
                    swipeLabel.text = "Swiped! (" + root.swipeCount + " total)"
                    statusLabel.text = "Swipe #" + root.swipeCount
                }

                Column {
                    id: flickColumn
                    objectName: "flickColumn"
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: 20
                        delegate: Rectangle {
                            objectName: "listItem_" + index
                            width: flickColumn.width
                            height: 36
                            radius: 8
                            color: index % 2 === 0 ? "#1a1a26" : "#15152a"

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: "Item " + (index + 1)
                                font.pixelSize: 13
                                color: "#e4e4ed"
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                text: "#" + (index + 1)
                                font.pixelSize: 11
                                color: "#555566"
                            }
                        }
                    }
                }
            }
        }

        // ── Pinch & Rotate Zone ──
        Rectangle {
            objectName: "pinchCard"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#12121a"
            border.color: "#2a2a3a"
            clip: true

            Label {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 12
                text: "PINCH & ROTATE"
                font.pixelSize: 14
                font.bold: true
                color: "#e4e4ed"
                z: 10
            }

            PinchArea {
                id: pinchArea
                objectName: "pinchArea"
                anchors.fill: parent

                pinch.target: pinchImage
                pinch.minimumScale: 0.3
                pinch.maximumScale: 5.0
                pinch.minimumRotation: -360
                pinch.maximumRotation: 360

                onPinchUpdated: {
                    root.currentScale = pinch.scale
                    root.currentRotation = pinch.rotation
                    statusLabel.text = "Scale: " + pinch.scale.toFixed(2) + " Rot: " + Math.round(pinch.rotation) + "°"
                }

                Rectangle {
                    id: pinchImage
                    objectName: "pinchTarget"
                    width: 120
                    height: 120
                    anchors.centerIn: parent
                    radius: 16
                    color: "transparent"
                    border.color: "#6366f1"
                    border.width: 3

                    Rectangle {
                        width: 60; height: 60
                        anchors.centerIn: parent
                        radius: 8
                        color: "#6366f120"
                        border.color: "#6366f1"
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: "V"
                            font.pixelSize: 28
                            font.bold: true
                            color: "#818cf8"
                        }
                    }

                    // Corner dots to show rotation
                    Repeater {
                        model: 4
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: "#22d3ee"
                            x: index < 2 ? 4 : parent.width - 12
                            y: index % 2 === 0 ? 4 : parent.height - 12
                        }
                    }
                }
            }

            Label {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 8
                text: "Pinch to zoom, two fingers to rotate"
                font.pixelSize: 11
                color: "#555566"
            }
        }
    }

    footer: ToolBar {
        objectName: "statusBar"
        background: Rectangle { color: "#16213e" }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8

            Label {
                id: statusLabel
                objectName: "statusLabel"
                text: "Ready - try tapping, swiping, and pinching"
                font.pixelSize: 13
                color: "#8888a0"
            }

            Item { Layout.fillWidth: true }

            Label {
                objectName: "portLabel"
                text: "veriCue: port " + (typeof vericuePort !== "undefined" ? vericuePort : "?")
                font.pixelSize: 12
                color: "#555566"
            }
        }
    }
}
