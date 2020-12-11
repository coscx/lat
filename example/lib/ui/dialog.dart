import 'package:flutter/material.dart';

class RenameDialog extends AlertDialog {
  RenameDialog({Widget contentWidget})
      : super(
          content: contentWidget,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blue, width: 3)),
        );
}

double btnHeight = 60;
double borderWidth = 2;

class RenameDialogContent extends StatefulWidget {
  final String title;
  final String cancelBtnTitle;
  final String okBtnTitle;
  final VoidCallback cancelBtnTap;
  final VoidCallback okBtnTap;
  final TextEditingController vc;
  RenameDialogContent(
      {@required this.title,
      this.cancelBtnTitle = "Cancel",
      this.okBtnTitle = "Ok",
      this.cancelBtnTap,
      this.okBtnTap,
      this.vc});

  @override
  _RenameDialogContentState createState() => _RenameDialogContentState();
}

class _RenameDialogContentState extends State<RenameDialogContent> {
  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(top: 20),
        height: 200,
        width: 10000,
        alignment: Alignment.bottomCenter,
        child: Column(
          children: [
            Container(
                alignment: Alignment.center,
                child: Text(
                  widget.title,
                  style: TextStyle(color: Colors.grey),
                )),
            Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(30, 0, 30, 0),
              child: TextField(
                style: TextStyle(color: Colors.black87),
                controller: widget.vc,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    )),
              ),
            ),
            Container(
              // color: Colors.red,
              height: btnHeight,
              margin: EdgeInsets.fromLTRB(0, 30, 0, 0),
              child: Column(
                children: [
                  Container(
                    // 按钮上面的横线
                    width: double.infinity,
                    color: Colors.blue,
                    height: borderWidth,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FlatButton(
                        onPressed: () {
                          widget.vc.text = "";
                          widget.cancelBtnTap();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          widget.cancelBtnTitle,
                          style: TextStyle(fontSize: 22, color: Colors.blue),
                        ),
                      ),
                      Container(
                        // 按钮中间的竖线
                        width: borderWidth,
                        color: Colors.blue,
                        height: btnHeight - borderWidth - borderWidth,
                      ),
                      FlatButton(
                          onPressed: () {
                            widget.okBtnTap();
                            Navigator.of(context).pop();
                            widget.vc.text = "";
                          },
                          child: Text(
                            widget.okBtnTitle,
                            style: TextStyle(fontSize: 22, color: Colors.blue),
                          )),
                    ],
                  ),
                ],
              ),
            )
          ],
        ));
  }
}
