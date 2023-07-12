import 'dart:io';
import 'dart:typed_data';

import 'package:flt_im_plugin_example/ui/peer_viewmodel.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:flt_im_plugin/message.dart';
import 'package:flt_im_plugin/value_util.dart';

class MessageView extends StatelessWidget {
  final Message message;
  final String uid;
  MessageView({required this.message, required this.uid});

  @override
  Widget build(BuildContext context) {
    bool isSelf = message.sender == uid;
    switch (message.type) {
      case MessageType.MESSAGE_TEXT:
        return _buildTextMessage(isSelf: isSelf, message: message, context: context);
      case MessageType.MESSAGE_IMAGE:
        return _buildImageMessage(isSelf: isSelf, message: message, context: context);
      default:
        return Container(
          alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
          child: Text('Unknow'),
        );
    }
  }

  //{
  //   "height": 1280,
  //   "littleImageURL": "http://localhost/images/701CCA97-6FCE-4B86-9188-BA30AA1190ED.png@256w_256h_0c",
  //   "raw": "{\"image\":\"http:\\/\\/localhost\\/images\\/701CCA97-6FCE-4B86-9188-BA30AA1190ED.png\",\"uuid\":\"A113EE7E-270A-4157-93E4-5F9236F632F7\",\"image2\":{\"url\":\"http:\\/\\/localhost\\/images\\/701CCA97-6FCE-4B86-9188-BA30AA1190ED.png\",\"width\":966,\"height\":1280}}",
  //   "width": 966,
  //   "uuid": "A113EE7E-270A-4157-93E4-5F9236F632F7",
  //   "imageURL": "http://localhost/images/701CCA97-6FCE-4B86-9188-BA30AA1190ED.png",
  //   "type": 2,
  //   "dict": {
  //     "image": "http://localhost/images/701CCA97-6FCE-4B86-9188-BA30AA1190ED.png",
  //     "image2": {
  //       "url": "http://localhost/images/701CCA97-6FCE-4B86-9188-BA30AA1190ED.png",
  //       "width": 966,
  //       "height": 1280
  //     },
  //     "uuid": "A113EE7E-270A-4157-93E4-5F9236F632F7"
  //   }
  // }
  _buildImageMessage({bool isSelf = true, required Message message, required BuildContext context}) {
    double width = ValueUtil.toDouble(message.content?['width']);
    double height = ValueUtil.toDouble(message.content?['height']);
    String imageURL = ValueUtil.toStr(message.content?['imageURL']);
    if (imageURL == null || imageURL.length == 0) {
      imageURL = ValueUtil.toStr(message.content?['url']);
    }

    PeerViewModel viewModel = Provider.of<PeerViewModel>(context, listen: false);

    return _buildWrapper(
      isSelf: isSelf,
      message: message,
      context: context,
      child: Container(
        color: Color(0xfff7f7f7),
        width: 100,
        height: 120,
        child: FutureBuilder(
          future: viewModel.getLocalCacheImage(url: imageURL),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container();
            }
            if (snapshot.hasData) {
              return Image.memory("" as Uint8List);
            } else {
              if (imageURL.startsWith("http://localhost")) {
                return Container();
              } else if (imageURL.startsWith('file:/')) {
                return Image.file(File(imageURL));
              }
              return Image.network(imageURL);
            }
          },
        ),
      ),
    );
  }

  // {
  //   "raw": "{\"text\":\"hello world\",\"uuid\":\"E8A29B16-C843-4605-9663-226245714025\"}",
  //   "uuid": "E8A29B16-C843-4605-9663-226245714025",
  //   "type": 1,
  //   "dict": {
  //     "text": "hello world",
  //     "uuid": "E8A29B16-C843-4605-9663-226245714025"
  //   },
  //   "text": "hello world"
  // }
  _buildTextMessage({bool isSelf = true, required Message message, required BuildContext context}) {
    String content = ValueUtil.toStr(message.content?['text']);
    return _buildWrapper(
        isSelf: isSelf,
        message: message,
        context: context,
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue),
          child: Text(
            content,
            style: TextStyle(color: Colors.white),
          ),
        ));
  }

  _buildWrapper({required bool isSelf, required Message message, required Widget child, required BuildContext context}) {
    return Container(
      margin: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf)
            Container(
              margin: EdgeInsets.only(right: 10),
              child: ClipOval(
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey,
                  child: Text(message.sender),
                  alignment: Alignment.center,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
            child: child,
          ),
          if (isSelf)
            Container(
              margin: EdgeInsets.only(left: 10),
              child: ClipOval(
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: Text(message.sender),
                ),
              ),
            )
        ],
      ),
    );
  }
}
