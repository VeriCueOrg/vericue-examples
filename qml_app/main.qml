import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: root
    objectName: "MainWindow"
    visible: true
    width: 480
    height: 640
    title: "veriCue QML Demo"
    color: "#1a1a2e"

    property int taskCount: 0
    property int completedCount: 0

    header: ToolBar {
        objectName: "toolbar"
        background: Rectangle { color: "#16213e" }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8

            Label {
                objectName: "appTitle"
                text: "Task Manager"
                font.pixelSize: 18
                font.bold: true
                color: "#e4e4ed"
            }

            Item { Layout.fillWidth: true }

            Label {
                objectName: "taskCounter"
                text: completedCount + "/" + taskCount + " done"
                font.pixelSize: 14
                color: "#818cf8"
            }
        }
    }

    ColumnLayout {
        objectName: "mainLayout"
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // --- Add Task Section ---
        Rectangle {
            objectName: "addTaskCard"
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 12
            color: "#12121a"
            border.color: "#2a2a3a"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Label {
                    text: "New Task"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#e4e4ed"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: taskInput
                        objectName: "taskInput"
                        Layout.fillWidth: true
                        placeholderText: "What needs to be done?"
                        color: "#e4e4ed"
                        font.pixelSize: 14

                        background: Rectangle {
                            radius: 8
                            color: "#1a1a26"
                            border.color: taskInput.activeFocus ? "#6366f1" : "#2a2a3a"
                            border.width: 1
                        }

                        Keys.onReturnPressed: addButton.clicked()
                    }

                    Button {
                        id: addButton
                        objectName: "addButton"
                        text: "Add"
                        enabled: taskInput.text.trim().length > 0

                        contentItem: Text {
                            text: addButton.text
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        background: Rectangle {
                            radius: 8
                            color: addButton.enabled ? (addButton.hovered ? "#818cf8" : "#6366f1") : "#2a2a3a"
                        }

                        onClicked: {
                            if (taskInput.text.trim().length > 0) {
                                taskModel.append({
                                    taskText: taskInput.text.trim(),
                                    done: false,
                                    priority: priorityCombo.currentText
                                })
                                root.taskCount++
                                taskInput.text = ""
                                statusLabel.text = "Task added"
                            }
                        }
                    }
                }
            }
        }

        // --- Priority & Filter ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ComboBox {
                id: priorityCombo
                objectName: "priorityCombo"
                model: ["Normal", "High", "Low"]
                Layout.preferredWidth: 140

                contentItem: Text {
                    text: priorityCombo.displayText
                    color: "#e4e4ed"
                    font.pixelSize: 13
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 8
                    color: "#1a1a26"
                    border.color: "#2a2a3a"
                    border.width: 1
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                objectName: "clearCompletedButton"
                text: "Clear Completed"
                enabled: root.completedCount > 0

                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#ef4444" : "#555566"
                    font.pixelSize: 13
                }

                background: Rectangle {
                    radius: 8
                    color: "transparent"
                    border.color: parent.enabled ? "#ef4444" : "#2a2a3a"
                    border.width: 1
                }

                onClicked: {
                    for (var i = taskModel.count - 1; i >= 0; i--) {
                        if (taskModel.get(i).done) {
                            taskModel.remove(i)
                            root.taskCount--
                            root.completedCount--
                        }
                    }
                    statusLabel.text = "Completed tasks cleared"
                }
            }
        }

        // --- Task List ---
        ListView {
            id: taskList
            objectName: "taskList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6

            model: ListModel {
                id: taskModel
                objectName: "taskModel"
            }

            delegate: Rectangle {
                objectName: "taskItem_" + index
                width: taskList.width
                height: 52
                radius: 10
                color: model.done ? "#0a1a0a" : "#12121a"
                border.color: model.done ? "#22d3ee33" : "#2a2a3a"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    CheckBox {
                        objectName: "taskCheck_" + index
                        checked: model.done
                        onCheckedChanged: {
                            if (checked !== model.done) {
                                taskModel.setProperty(index, "done", checked)
                                if (checked) root.completedCount++
                                else root.completedCount--
                                statusLabel.text = checked ? "Task completed" : "Task reopened"
                            }
                        }

                        indicator: Rectangle {
                            width: 22; height: 22
                            radius: 6
                            color: parent.checked ? "#34d399" : "transparent"
                            border.color: parent.checked ? "#34d399" : "#555566"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "#fff"
                                font.pixelSize: 14
                                visible: parent.parent.checked
                            }
                        }
                    }

                    Label {
                        objectName: "taskLabel_" + index
                        Layout.fillWidth: true
                        text: model.taskText
                        color: model.done ? "#555566" : "#e4e4ed"
                        font.pixelSize: 14
                        font.strikeout: model.done
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        objectName: "priorityBadge_" + index
                        width: 50; height: 22
                        radius: 6
                        visible: model.priority !== "Normal"
                        color: model.priority === "High" ? "#ef444420" : "#6366f120"

                        Label {
                            anchors.centerIn: parent
                            text: model.priority
                            font.pixelSize: 10
                            font.bold: true
                            color: model.priority === "High" ? "#ef4444" : "#818cf8"
                        }
                    }
                }
            }

            // Empty state
            Label {
                objectName: "emptyLabel"
                anchors.centerIn: parent
                visible: taskModel.count === 0
                text: "No tasks yet.\nAdd one above!"
                color: "#555566"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }

        // --- Progress ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ProgressBar {
                id: progressBar
                objectName: "progressBar"
                Layout.fillWidth: true
                from: 0; to: 1
                value: root.taskCount > 0 ? root.completedCount / root.taskCount : 0

                background: Rectangle {
                    radius: 4; height: 8; color: "#1a1a26"
                }

                contentItem: Item {
                    Rectangle {
                        width: progressBar.visualPosition * parent.width
                        height: 8; radius: 4
                        color: progressBar.value >= 1.0 ? "#34d399" : "#6366f1"
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            Label {
                objectName: "progressLabel"
                text: root.taskCount > 0
                    ? Math.round(root.completedCount / root.taskCount * 100) + "% complete"
                    : "No tasks"
                font.pixelSize: 12
                color: "#8888a0"
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
                text: "Ready"
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
