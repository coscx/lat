import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'peer_viewmodel.dart';
import 'message_view.dart';

class PeerPage extends StatelessWidget {
  final Map params;
  PeerPage({this.params});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PeerViewModel(params: params),
      child: Consumer<PeerViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Peer'),
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child: Text(
                      "操作",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(left: 10),
                              child: TextField(
                                controller: TextEditingController(text: model.text),
                                textInputAction: TextInputAction.send,
                                onChanged: (text) {
                                  model.text = text;
                                },
                                onSubmitted: (text) {
                                  FocusScope.of(context).requestFocus(FocusNode());
                                  model.sendTextMessage();
                                },
                              ),
                            ),
                          ),
                          FlatButton(
                              onPressed: () {
                                FocusScope.of(context).requestFocus(FocusNode());
                                model.sendTextMessage();
                              },
                              child: Text('发送文本'))
                        ],
                      )),
                      FlatButton(
                          onPressed: () async {
                            PickedFile pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
                            model.sendImageMessage(await pickedFile.readAsBytes());
                          },
                          child: Text('发送图片')),
                      // FlatButton(
                      //     onPressed: () async {
                      //       PickedFile pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
                      //       model.sendImageMessage(await pickedFile.readAsBytes());
                      //     },
                      //     child: Text('发送Video')),
                      // FlatButton(
                      //     onPressed: () async {
                      //       PickedFile pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
                      //       model.sendImageMessage(await pickedFile.readAsBytes());
                      //     },
                      //     child: Text('发送Audio')),
                      // FlatButton(
                      //     onPressed: () async {
                      //       PickedFile pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
                      //       model.sendImageMessage(await pickedFile.readAsBytes());
                      //     },
                      //     child: Text('发送Location')),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child: Text(
                      "聊天记录",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...model.messages.map((message) {
                    return MessageView(
                      message: message,
                      uid: model.params.currentUID,
                    );
                  })
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
