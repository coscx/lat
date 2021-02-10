package com.example.flt_im_plugin;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.database.sqlite.SQLiteDatabase;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.os.AsyncTask;
import android.os.HandlerThread;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

//import com.amap.api.services.core.LatLonPoint;
//import com.amap.api.services.geocoder.GeocodeResult;
//import com.amap.api.services.geocoder.GeocodeSearch;
//import com.amap.api.services.geocoder.RegeocodeQuery;
//import com.amap.api.services.geocoder.RegeocodeResult;
import com.beetle.bauhinia.api.IMHttpAPI;
import com.beetle.bauhinia.api.body.PostDeviceToken;
import com.beetle.bauhinia.db.CustomerMessageDB;
import com.beetle.bauhinia.db.EPeerMessageDB;
import com.beetle.bauhinia.db.GroupMessageDB;
import com.beetle.bauhinia.db.IMessage;
import com.beetle.bauhinia.db.IMessageDB;
import com.beetle.bauhinia.db.MessageFlag;
import com.beetle.bauhinia.db.MessageIterator;
import com.beetle.bauhinia.db.PeerMessageDB;
import com.beetle.bauhinia.db.message.ACK;
import com.beetle.bauhinia.db.message.Audio;
import com.beetle.bauhinia.db.message.GroupNotification;
import com.beetle.bauhinia.db.message.GroupVOIP;
import com.beetle.bauhinia.db.message.Image;
import com.beetle.bauhinia.db.message.Location;
import com.beetle.bauhinia.db.message.MessageContent;
import com.beetle.bauhinia.db.message.P2PSession;
import com.beetle.bauhinia.db.message.Revoke;
import com.beetle.bauhinia.db.message.Secret;
import com.beetle.bauhinia.db.message.Text;
import com.beetle.bauhinia.db.message.TimeBase;
import com.beetle.bauhinia.db.message.VOIP;
import com.beetle.bauhinia.db.message.Video;
import com.beetle.bauhinia.handler.CustomerMessageHandler;
import com.beetle.bauhinia.handler.GroupMessageHandler;
import com.beetle.bauhinia.handler.PeerMessageHandler;
import com.beetle.bauhinia.handler.SyncKeyHandler;
import com.beetle.bauhinia.outbox.OutboxObserver;
import com.beetle.bauhinia.outbox.PeerOutbox;
import com.beetle.bauhinia.outbox.GroupOutbox;
import com.beetle.bauhinia.toolbar.emoticon.EmoticonManager;
import com.beetle.bauhinia.tools.AudioUtil;
import com.beetle.bauhinia.tools.FileCache;
import com.beetle.bauhinia.tools.FileDownloader;
import com.beetle.bauhinia.tools.TimeUtil;
import com.beetle.bauhinia.tools.VideoUtil;
import com.beetle.im.GroupMessageObserver;
import com.beetle.im.IMMessage;
import com.beetle.im.IMService;
import com.beetle.im.IMServiceObserver;
import com.beetle.im.MessageACK;
import com.beetle.im.PeerMessageObserver;
import com.beetle.im.SystemMessageObserver;

import org.apache.http.HttpResponse;
import org.apache.http.HttpStatus;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicHeader;
import org.apache.http.protocol.HTTP;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import rx.android.schedulers.AndroidSchedulers;
import rx.functions.Action1;
import top.zibin.luban.Luban;
import top.zibin.luban.OnCompressListener;

import static android.provider.Settings.Secure;
import static android.provider.Settings.Secure.ANDROID_ID;

/** FltImPlugin */
public class FltImPlugin implements FlutterPlugin,
        MethodCallHandler, EventChannel.StreamHandler,
        ActivityAware,
        PluginRegistry.ActivityResultListener,
        DefaultLifecycleObserver,
        OutboxObserver,
        FileDownloader.FileDownloaderObserver,
        IMServiceObserver,
        GroupMessageObserver,
        SystemMessageObserver,
        PeerMessageObserver {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private EventChannel.EventSink eventSink;
  private Context context;
  Registrar registrar;
  ActivityPluginBinding activityPluginBinding;
  Activity activity;
  private HandlerThread imThread;//处理im消息的线程
  private Lifecycle lifecycle;
  private long currentUID;
  private long conversationID;
  protected ArrayList<IMessage> messages = new ArrayList<IMessage>();
  private List<Conversation> conversations;
  protected long groupID;
  protected String groupName;
  public void initInstance(BinaryMessenger messeger, Context context) {
    channel = new MethodChannel(messeger, "flt_im_plugin");
    channel.setMethodCallHandler(this);
    EventChannel eventChannel = new EventChannel(messeger, "flt_im_plugin_event");
    eventChannel.setStreamHandler(this);
    this.context = context;
  }

  /// v1 的接口
  public static void registerWith(Registrar registrar) {
    FltImPlugin instance = new FltImPlugin();
    instance.initInstance(registrar.messenger(), registrar.context());
    instance.registrar = registrar;
    registrar.addActivityResultListener(instance);
  }

  private void dispose() {
    channel.setMethodCallHandler(null);
    channel = null;
  }

  private void disposeActivity() {
    this.activityPluginBinding.removeActivityResultListener(this);
    this.activity = null;
    this.activityPluginBinding = null;
    lifecycle.removeObserver(this);
  }

  private void attachToActivity(ActivityPluginBinding activityPluginBinding) {
    this.activityPluginBinding = activityPluginBinding;
    activityPluginBinding.addActivityResultListener(this);
    this.activity = activityPluginBinding.getActivity();
    this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityPluginBinding);
    lifecycle.addObserver(this);
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    initInstance(flutterPluginBinding.getBinaryMessenger(), flutterPluginBinding.getApplicationContext());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    dispose();
  }

  /// ActivityAware
  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    attachToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    disposeActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    attachToActivity(binding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    disposeActivity();
  }

  /// ActivityResultListener
  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    return false;
  }

  /// DefaultLifecycleObserver
  @Override
  public void onCreate(@NonNull LifecycleOwner owner) {

  }

  @Override
  public void onStart(@NonNull LifecycleOwner owner) {

  }

  @Override
  public void onResume(@NonNull LifecycleOwner owner) {
    IMService.getInstance().enterForeground();
  }

  @Override
  public void onPause(@NonNull LifecycleOwner owner) {

  }

  @Override
  public void onStop(@NonNull LifecycleOwner owner) {
    if (!isAppOnForeground()) {
      IMService.getInstance().enterBackground();
    }
  }

  @Override
  public void onDestroy(@NonNull LifecycleOwner owner) {

  }

  /// methodobserver
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "init": {
        init(call.arguments, result);
        break;
      }
      case "login": {
        login(call.arguments, result);
        break;
      }
      case "logout": {
        logout(call.arguments, result);
        break;
      }
      case "createConversion": {
        createConversion(call.arguments, result);
        break;
      }
      case "createGroupConversion": {
        createGroupConversion(call.arguments, result);
        break;
      }
      case "loadData": {
        loadData(call.arguments, result);
        break;
      }
      case "loadEarlierData": {
        loadEarlierData(call.arguments, result);
        break;
      }
      case "loadLateData": {
        loadLateData(call.arguments, result);
        break;
      }
      case "sendMessage": {
        sendMessage(call.arguments, result);
        break;
      }
      case "sendGroupMessage": {
        sendGroupMessage(call.arguments, result);
        break;
      }
      case "getLocalCacheImage": {
        getLocalCacheImage(call.arguments, result);
        break;
      }
      case "getLocalMediaURL": {
        getLocalMediaURL(call.arguments, result);
        break;
      }
      case "getConversations": {
        getConversations(call.arguments, result);
        break;
      }
      case "deleteConversation": {
        deleteConversation(call.arguments, result);
        break;
      }
      case "clearReadCount": {
        clearReadCount(call.arguments, result);
        break;
      }
      case "clearGroupReadCount": {
        clearGroupReadCount(call.arguments, result);
        break;
      }
      default:
        result.notImplemented();
    }
  }



  /// api
  private void getConversations(Object arg, final  Result result) {
    loadConversations();
    result.success(resultSuccess(convertConversionToMapList(conversations)));
  }

  private void deleteConversation(Object arg, final  Result result) {
    Map argMap = convertToMap(arg);
    String cid = (String)argMap.get("cid"); // imnode2.gobelieve.io
    long l_cid = Long.parseLong(cid);

    int pos = findConversationPosition(l_cid, Conversation.CONVERSATION_PEER);
    if (pos != -1) {
      Conversation conversation = conversations.get(pos);
      ConversationDB.getInstance().removeConversation(conversation);
      PeerMessageDB.getInstance().clearConversation(l_cid);
    } else {
      pos = findConversationPosition(l_cid, Conversation.CONVERSATION_GROUP);
      if (pos != -1) {
        Conversation conversation = conversations.get(pos);
        ConversationDB.getInstance().removeConversation(conversation);
        GroupMessageDB.getInstance().clearConversation(l_cid);

      }
    }
    result.success(resultSuccess("完成"));
  }

  void loadConversations() {
    conversations = ConversationDB.getInstance().getConversations();
    for (Conversation conv : conversations) {
      if (conv.type == Conversation.CONVERSATION_PEER) {
        IMessage msg = PeerMessageDB.getInstance().getLastMessage(conv.cid);
        conv.message = msg;
        updatePeerConversationName(conv);
        updateConvNotificationDesc(conv);
        updateConversationDetail(conv);
      } else if (conv.type == Conversation.CONVERSATION_PEER_SECRET) {
        IMessage msg = EPeerMessageDB.getInstance().getLastMessage(conv.cid);
        conv.message = msg;
        updatePeerConversationName(conv);
        updateConvNotificationDesc(conv);
        updateConversationDetail(conv);
      } else if (conv.type == Conversation.CONVERSATION_GROUP) {
        IMessage msg = GroupMessageDB.getInstance().getLastMessage(conv.cid);
        conv.message = msg;
        updateGroupConversationName(conv);
        updateConvNotificationDesc(conv);
        updateConversationDetail(conv);
      } else if (conv.type == Conversation.CONVERSATION_CUSTOMER_SERVICE) {
//        if (conv.cid != KEFU_ID) {
//          continue;
//        }
//        IMessage msg = CustomerMessageDB.getInstance().getLastMessage(conv.cid);
//        conv.message = msg;
//        conv.setName("客服");
//        updateConvNotificationDesc(conv);
//        updateConversationDetail(conv);
//        customerExists = true;
      }
    }

    Comparator<Conversation> cmp = new Comparator<Conversation>() {
      public int compare(Conversation c1, Conversation c2) {

        int t1 = 0;
        int t2 = 0;
        if (c1.message != null) {
          t1 = c1.message.timestamp;
        }
        if (c2.message != null) {
          t2 = c2.message.timestamp;
        }

        if (t1 > t2) {
          return -1;
        } else if (t1 == t2) {
          return 0;
        } else {
          return 1;
        }

      }
    };
    Collections.sort(conversations, cmp);
  }



  private void init(Object arg, final Result result) {

      Map argMap = convertToMap(arg);
      String host = (String)argMap.get("host"); // imnode2.gobelieve.io
      String apiURL = (String)argMap.get("apiURL"); // http://api.gobelieve.io

      imThread = new HandlerThread("im_service");
      imThread.start();
      IMService mIMService = IMService.getInstance();
      mIMService.setHost(host);
      IMHttpAPI.setAPIURL(apiURL);
      String androidID = Secure.getString(context.getContentResolver(),
              Secure.ANDROID_ID);
      //设置设备唯一标识,用于多点登录时设备校验
      mIMService.setDeviceID(androidID);
      mIMService.setLooper(imThread.getLooper());
      //监听网路状态变更
      IMService.getInstance().registerConnectivityChangeReceiver(context.getApplicationContext());
      //可以在登录成功后，设置每个用户不同的消息存储目录
      FileCache fc = FileCache.getInstance();
      fc.setDir(context.getDir("cache", Context.MODE_PRIVATE));
      mIMService.setPeerMessageHandler(PeerMessageHandler.getInstance());
      mIMService.setGroupMessageHandler(GroupMessageHandler.getInstance());
      mIMService.setCustomerMessageHandler(CustomerMessageHandler.getInstance());
      //预先做dns查询
      try {
        refreshHost(host, getDomainName(apiURL));
      } catch (URISyntaxException e) {
      }
      //表情资源初始化
      EmoticonManager.getInstance().init(context);
      result.success(resultSuccess("init success"));
  }

  public String getDomainName(String url) throws URISyntaxException {
    URI uri = new URI(url);
    String domain = uri.getHost();
    return domain.startsWith("www.") ? domain.substring(4) : domain;
  }

  private void login(Object arg, final Result result) {
      Map map = convertToMap(arg);
      String uid = (String)map.get("uid");
      long l_uid =0;
      try {
         l_uid = Long.parseLong(uid);

      } catch (Exception e) {
        result.success(resultError("login fail", 1));
      }
      String token = (String)map.get("token");

      if (token == null || token.isEmpty()) {
        token = login(uid);
      }
      if (token == null || token.isEmpty()) {
        result.success(resultError("login fail", 1));
      } else {
        IMService.getInstance().stop();
        PeerMessageDB.getInstance().setDb(null);
        EPeerMessageDB.getInstance().setDb(null);
        GroupMessageDB.getInstance().setDb(null);
        CustomerMessageDB.getInstance().setDb(null);
        ConversationDB.getInstance().setDb(null);
        openDB(l_uid);

        PeerMessageHandler.getInstance().setUID(l_uid);
        GroupMessageHandler.getInstance().setUID(l_uid);
        IMHttpAPI.setToken(token);
        IMService.getInstance().setToken(token);

        SyncKeyHandler handler = new SyncKeyHandler(context.getApplicationContext(), "sync_key");
        handler.load();

        HashMap<Long, Long> groupSyncKeys = handler.getSuperGroupSyncKeys();
        IMService.getInstance().clearSuperGroupSyncKeys();
        for (Map.Entry<Long, Long> e : groupSyncKeys.entrySet()) {
          IMService.getInstance().addSuperGroupSyncKey(e.getKey(), e.getValue());
        }
        IMService.getInstance().setSyncKey(handler.getSyncKey());
        IMService.getInstance().setSyncKeyHandler(handler);
        IMService.getInstance().start();

        String deviceToken = null;
        if (token != null && deviceToken != null && deviceToken.length() > 0) {
          PostDeviceToken tokenBody = new PostDeviceToken();
          tokenBody.xgDeviceToken = deviceToken;
          IMHttpAPI.Singleton().bindDeviceToken(tokenBody)
                  .observeOn(AndroidSchedulers.mainThread())
                  .subscribe(new Action1<Object>() {
                    @Override
                    public void call(Object obj) {

                    }
                  }, new Action1<Throwable>() {
                    @Override
                    public void call(Throwable throwable) {

                    }
                  });
        }

        PeerOutbox.getInstance().addObserver(this);
        IMService.getInstance().addObserver(this);
        IMService.getInstance().addPeerObserver(this);
        IMService.getInstance().addGroupObserver(this);
        IMService.getInstance().addSystemObserver(this);
        FileDownloader.getInstance().addObserver(this);
        this.conversations = ConversationDB.getInstance().getConversations();
        result.success(resultSuccess("login success"));
      }

  }

  private void logout(Object arg, final Result result) {
    IMService.getInstance().stop();
  }

  protected IMessageDB messageDB;
  private void createConversion(Object arg, final Result result) {
      Map argMap = convertToMap(arg);;
      String currentUID = (String)argMap.get("currentUID");
      String peerUID = (String)argMap.get("peerUID");
      boolean secret = (int)argMap.get("secret") > 0;
      this.currentUID = Long.parseLong(currentUID);
      this.conversationID = Long.parseLong(peerUID);

      messageDB = secret ? EPeerMessageDB.getInstance():PeerMessageDB.getInstance();
      result.success(resultSuccess("createConversion success"));
  }

  private void loadData(Object arg, final Result result) {
      Map argMap = convertToMap(arg);
      Object msd = argMap.get("messageID");
      int messageID = msd == null ? 0 : (int)msd;
      List<IMessage> messages;
      if (messageID > 0) {
        messages = this.loadConversationData(messageID);
      } else {
        messages = this.loadConversationData();
      }
      wrapperMessages(messages);
      result.success(resultSuccess(convertToMapList(messages)));
  }

  private void loadEarlierData(Object arg, final Result result) {
    Map argMap = convertToMap(arg);
    long messageID = Long.parseLong(argMap.get("messageID").toString());
    ArrayList<IMessage> messages = new ArrayList<IMessage>();
    int count = 0;
    MessageIterator iter = createForwardMessageIterator(messageID);
    while (iter != null) {
      IMessage msg = iter.next();
      if (msg == null) {
        break;
      }
      msg.isOutgoing = (msg.sender == currentUID);
      messages.add(0, msg);
      if (++count >= pageSize) {
        break;
      }
    }
    wrapperMessages(messages);
    result.success(resultSuccess(convertToMapList(messages)));
  }

  private void loadLateData(Object arg, final Result result) {
    Map argMap = convertToMap(arg);
    long messageID = Long.parseLong(argMap.get("messageID").toString());
    ArrayList<IMessage> messages = new ArrayList<IMessage>();
    int count = 0;
    MessageIterator iter = createBackwardMessageIterator(messageID);
    while (true) {
      IMessage msg = iter.next();
      if (msg == null) {
        break;
      }

      msg.isOutgoing = (msg.sender == currentUID);
      messages.add(msg);
      if (++count >= pageSize) {
        break;
      }
    }
    wrapperMessages(messages);
    result.success(resultSuccess(convertToMapList(messages)));
  }
  private void createGroupConversion(Object arg, final Result result) {
    Map argMap = convertToMap(arg);;
    String currentUID = (String)argMap.get("currentUID");
    String groupUID = (String)argMap.get("groupUID");
    this.currentUID = Long.parseLong(currentUID);
    this.conversationID = Long.parseLong(groupUID);
    messageDB = GroupMessageDB.getInstance();
    result.success(resultSuccess("createGroupConversion success"));
  }


  IMessage newOutMessage(Map arg) {
    IMessage msg = new IMessage();
    msg.sender = Long.parseLong((String)arg.get("sender"));
    msg.receiver = Long.parseLong((String)arg.get("receiver"));
    msg.secret = (int)arg.get("secret") > 0;
    return msg;
  }

  private void sendMessage(Object arg, final Result result) {
    Map params = (Map)arg;
    Map argMap = (Map)params.get("message");
    MessageContent.MessageType type = _getMessageTypeFromNumber((int)params.get("type"));
    final IMessage imsg = newOutMessage(argMap);

    if (type == MessageContent.MessageType.MESSAGE_TEXT) {
      String rawContent = (String)argMap.get("rawContent");
      imsg.setContent(Text.newText(rawContent));
      _sendMessage(imsg, result);
    } else if (type == MessageContent.MessageType.MESSAGE_IMAGE) {
      byte[] bitmap = (byte[])argMap.get("image");
      Bitmap bmp = BitmapFactory.decodeByteArray(bitmap, 0, bitmap.length);
      if(bmp.getWidth()>bmp.getHeight()) {
        Matrix matrix = new Matrix();
        matrix.postRotate(90);
        bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.getWidth(), bmp.getHeight(), matrix, true);
      }
      double w = bmp.getWidth();
      double h = bmp.getHeight();
      double rate = w > h ? w/h : h/w;


      int scalePolicy = -1;// 0 origin, 1 max 1280, 2  min 800
      if (w <= 1280 && h <= 1280) {
        scalePolicy = 0;
      } else if (w > 1280) {
        if (rate <= 2) {
          //max 1280
          scalePolicy = 1;
        } else {
          if (h <= 1280){
            scalePolicy = 0;
          } else if (h > 1280) {
            //min 800
            scalePolicy = 2;
          }
        }
      } else if (h > 1280) {
        if (rate <= 2) {
          //max 1280
          scalePolicy = 1;
        } else {
          //w <= 1280
          scalePolicy = 0;
        }
      }
      double newHeight = 0;
      double newWidth = 0;
      Bitmap bigBMP;
      if (scalePolicy == 0) {
        bigBMP = bmp;
        newWidth = bmp.getWidth();
        newHeight = bmp.getHeight();
      } else if (scalePolicy == 1) {
        if (w > h) {
          newWidth = 1280;
          newHeight = 1280/rate;
        } else {
          newHeight = 1280;
          newWidth = 1280/rate;
        }
        bigBMP = Bitmap.createScaledBitmap(bmp, (int)newWidth, (int)newHeight, true);
      } else if (scalePolicy == 2) {
        if (w > h) {
          newWidth = 800*rate;
          newHeight = 800;
        } else {
          newHeight = 800*rate;
          newWidth = 800;
        }
        bigBMP = Bitmap.createScaledBitmap(bmp, (int)newWidth, (int)newHeight, true);
      } else {
        bigBMP = bmp;
        newWidth = bmp.getWidth();
        newHeight = bmp.getHeight();
      }
      bigBMP = bmp;
      newHeight= bmp.getWidth();
      newWidth = bmp.getHeight();
      double sw = 256.0;
      double sh = 256.0*h/w;

      Bitmap thumbnail = Bitmap.createScaledBitmap(bmp, (int)sw, (int)sh, true);
      ByteArrayOutputStream os = new ByteArrayOutputStream();
      bigBMP.compress(Bitmap.CompressFormat.JPEG, 100, os);
      ByteArrayOutputStream os2 = new ByteArrayOutputStream();
      thumbnail.compress(Bitmap.CompressFormat.JPEG, 100, os2);
      String originURL = localImageURL();
      String thumbURL = localImageURL();
      try {
        FileCache.getInstance().storeByteArray(originURL, os);
        FileCache.getInstance().storeByteArray(thumbURL, os2);
        String path = FileCache.getInstance().getCachedFilePath(originURL);
        String thumbPath = FileCache.getInstance().getCachedFilePath(thumbURL);

        String tpath = path ;//+ "@256w_256h_0c";
        File f = new File(thumbPath);
        File t = new File(tpath);
        //f.renameTo(t);
        final String[] newPath = new String[1];
        final double finalNewWidth = newWidth;
        final double finalNewHeight = newHeight;
        Luban.with(context) // 初始化
                .load(t) // 要压缩的图片
                .ignoreBy(100)
                .putGear(3)
                .setCompressListener(new OnCompressListener() {
                  @Override
                  public void onStart() {
                  }
                  @Override
                  public void onSuccess(File newFile) {
                    // 压缩成功后调用，返回压缩后的图片文件
                    // 获取返回的图片地址 newfile
                    newPath[0] =newFile.getAbsolutePath();
                    imsg.setContent(Image.newImage("file:" +  newPath[0], (int) finalNewWidth, (int) finalNewHeight));
                    _sendMessage(imsg, result);
                  }
                  @Override
                  public void onError(Throwable e) {
                  }
                }).launch(); // 启动压缩


      } catch (IOException e) {
        result.success(resultError("发送失败", 1));
      }

    } else if (type == MessageContent.MessageType.MESSAGE_VIDEO) {
      String path = (String)argMap.get("path");
      String thumbPath = (String)argMap.get("thumbPath");
      File f = new File(path);
      File thumbFile = new File(thumbPath);
      if (!f.exists() || !thumbFile.exists()) {
        result.success(resultError("文件不存在", 1));
        return ;
      }
      final VideoUtil.Metadata meta = VideoUtil.getVideoMetadata(path);

      if (!TextUtils.isEmpty(meta.videoMime) && !VideoUtil.isH264(meta.videoMime)) {
        result.success(resultError("文件格式不支持", 2));
        return;
      }

      if (!TextUtils.isEmpty(meta.audioMime) && !VideoUtil.isAcc(meta.audioMime)) {
        result.success(resultError("文件格式不支持", 2));
        return;
      }

      final int duration = meta.duration/1000;//单位秒
      try {
        String thumbURL = localImageURL();
        FileCache.getInstance().moveFile(thumbURL, thumbPath);
        String p1 = FileCache.getInstance().getCachedFilePath(thumbURL);

        final String videoURL = localVideoURL();
        FileCache.getInstance().moveFile(videoURL, path);
        imsg.setContent(Video.newVideo(videoURL, "file:" + p1, meta.width, meta.height, duration));
        _sendMessage(imsg, result);
      } catch (IOException e) {
        result.success(resultError("发送失败", 3));
      }

    } else if (type == MessageContent.MessageType.MESSAGE_AUDIO) {
      String tfile = (String)argMap.get("path");
      try {
        long mduration = AudioUtil.getAudioDuration(tfile);
        long duration = mduration/1000;
        String url = localAudioURL();
        Audio audio = Audio.newAudio(url, duration);
        FileInputStream is = new FileInputStream(new File(tfile));
        FileCache.getInstance().storeFile(audio.url, is);
        imsg.setContent(audio);
        _sendMessage(imsg, result);
      } catch (IllegalStateException e) {
        result.success(resultError("发送失败", 3));
      } catch (IOException e) {
        result.success(resultError("发送失败", 3));
      }
    } else if (type == MessageContent.MessageType.MESSAGE_LOCATION) {
      float latitude = (float)argMap.get("latitude");
      float longitude = (float)argMap.get("longitude");
      String address = (String)argMap.get("address");
      Location loc = Location.newLocation(latitude, longitude);
      loc.address = address;
      if (TextUtils.isEmpty(loc.address)) {
        queryLocation(imsg);
      }
      _sendMessage(imsg, result);
    } else {
      result.success(resultSuccess("暂不支持"));
    }
  }

  void _sendMessage(IMessage imsg, final Result result) {
    imsg.timestamp = now();
    imsg.isOutgoing = true;
    saveMessage(imsg);
    loadUserName(imsg);
    PeerOutbox.getInstance().sendMessage(imsg);
    result.success(resultSuccess(convertToMap(imsg)));
    onNewMessage(imsg, imsg.receiver);
  }
  private void sendGroupMessage(Object arg, final Result result) {
    Map params = (Map)arg;
    Map argMap = (Map)params.get("message");
    MessageContent.MessageType type = _getMessageTypeFromNumber((int)params.get("type"));
    final IMessage imsg = newOutMessage(argMap);

    if (type == MessageContent.MessageType.MESSAGE_TEXT) {
      String rawContent = (String)argMap.get("rawContent");
      imsg.setContent(Text.newText(rawContent));
      _sendGroupMessage(imsg, result);
    } else if (type == MessageContent.MessageType.MESSAGE_IMAGE) {
      byte[] bitmap = (byte[])argMap.get("image");
      Bitmap bmp = BitmapFactory.decodeByteArray(bitmap, 0, bitmap.length);
      if(bmp.getWidth()>bmp.getHeight()) {
        Matrix matrix = new Matrix();
        matrix.postRotate(90);
        bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.getWidth(), bmp.getHeight(), matrix, true);
      }
      double w = bmp.getWidth();
      double h = bmp.getHeight();
      double rate = w > h ? w/h : h/w;


      int scalePolicy = -1;// 0 origin, 1 max 1280, 2  min 800
      if (w <= 1280 && h <= 1280) {
        scalePolicy = 0;
      } else if (w > 1280) {
        if (rate <= 2) {
          //max 1280
          scalePolicy = 1;
        } else {
          if (h <= 1280){
            scalePolicy = 0;
          } else if (h > 1280) {
            //min 800
            scalePolicy = 2;
          }
        }
      } else if (h > 1280) {
        if (rate <= 2) {
          //max 1280
          scalePolicy = 1;
        } else {
          //w <= 1280
          scalePolicy = 0;
        }
      }
      double newHeight = 0;
      double newWidth = 0;
      Bitmap bigBMP;
      if (scalePolicy == 0) {
        bigBMP = bmp;
        newWidth = bmp.getWidth();
        newHeight = bmp.getHeight();
      } else if (scalePolicy == 1) {
        if (w > h) {
          newWidth = 1280;
          newHeight = 1280/rate;
        } else {
          newHeight = 1280;
          newWidth = 1280/rate;
        }
        bigBMP = Bitmap.createScaledBitmap(bmp, (int)newWidth, (int)newHeight, true);
      } else if (scalePolicy == 2) {
        if (w > h) {
          newWidth = 800*rate;
          newHeight = 800;
        } else {
          newHeight = 800*rate;
          newWidth = 800;
        }
        bigBMP = Bitmap.createScaledBitmap(bmp, (int)newWidth, (int)newHeight, true);
      } else {
        bigBMP = bmp;
        newWidth = bmp.getWidth();
        newHeight = bmp.getHeight();
      }
      bigBMP = bmp;
      newHeight= bmp.getWidth();
      newWidth = bmp.getHeight();
      double sw = 256.0;
      double sh = 256.0*h/w;

      Bitmap thumbnail = Bitmap.createScaledBitmap(bmp, (int)sw, (int)sh, true);
      ByteArrayOutputStream os = new ByteArrayOutputStream();
      bigBMP.compress(Bitmap.CompressFormat.JPEG, 100, os);
      ByteArrayOutputStream os2 = new ByteArrayOutputStream();
      thumbnail.compress(Bitmap.CompressFormat.JPEG, 100, os2);
      String originURL = localImageURL();
      String thumbURL = localImageURL();
      try {
        FileCache.getInstance().storeByteArray(originURL, os);
        FileCache.getInstance().storeByteArray(thumbURL, os2);
        String path = FileCache.getInstance().getCachedFilePath(originURL);
        String thumbPath = FileCache.getInstance().getCachedFilePath(thumbURL);

        String tpath = path ;//+ "@256w_256h_0c";
        File f = new File(thumbPath);
        File t = new File(tpath);
        //f.renameTo(t);
        final String[] newPath = new String[1];
        final double finalNewWidth = newWidth;
        final double finalNewHeight = newHeight;
        Luban.with(context) // 初始化
                .load(t) // 要压缩的图片
                .ignoreBy(100)
                .putGear(3)
                .setCompressListener(new OnCompressListener() {
                  @Override
                  public void onStart() {
                  }
                  @Override
                  public void onSuccess(File newFile) {
                    // 压缩成功后调用，返回压缩后的图片文件
                    // 获取返回的图片地址 newfile
                    newPath[0] =newFile.getAbsolutePath();
                    imsg.setContent(Image.newImage("file:" +  newPath[0], (int) finalNewWidth, (int) finalNewHeight));
                    _sendGroupMessage(imsg, result);
                  }
                  @Override
                  public void onError(Throwable e) {
                  }
                }).launch(); // 启动压缩


      } catch (IOException e) {
        result.success(resultError("发送失败", 1));
      }

    } else if (type == MessageContent.MessageType.MESSAGE_VIDEO) {
      String path = (String)argMap.get("path");
      String thumbPath = (String)argMap.get("thumbPath");
      File f = new File(path);
      File thumbFile = new File(thumbPath);
      if (!f.exists() || !thumbFile.exists()) {
        result.success(resultError("文件不存在", 1));
        return ;
      }
      final VideoUtil.Metadata meta = VideoUtil.getVideoMetadata(path);

      if (!TextUtils.isEmpty(meta.videoMime) && !VideoUtil.isH264(meta.videoMime)) {
        result.success(resultError("文件格式不支持", 2));
        return;
      }

      if (!TextUtils.isEmpty(meta.audioMime) && !VideoUtil.isAcc(meta.audioMime)) {
        result.success(resultError("文件格式不支持", 2));
        return;
      }

      final int duration = meta.duration/1000;//单位秒
      try {
        String thumbURL = localImageURL();
        FileCache.getInstance().moveFile(thumbURL, thumbPath);
        String p1 = FileCache.getInstance().getCachedFilePath(thumbURL);

        final String videoURL = localVideoURL();
        FileCache.getInstance().moveFile(videoURL, path);
        imsg.setContent(Video.newVideo(videoURL, "file:" + p1, meta.width, meta.height, duration));
        _sendGroupMessage(imsg, result);
      } catch (IOException e) {
        result.success(resultError("发送失败", 3));
      }

    } else if (type == MessageContent.MessageType.MESSAGE_AUDIO) {
      String tfile = (String)argMap.get("path");
      try {
        long mduration = AudioUtil.getAudioDuration(tfile);
        long duration = mduration/1000;
        String url = localAudioURL();
        Audio audio = Audio.newAudio(url, duration);
        FileInputStream is = new FileInputStream(new File(tfile));
        FileCache.getInstance().storeFile(audio.url, is);
        imsg.setContent(audio);
        _sendGroupMessage(imsg, result);
      } catch (IllegalStateException e) {
        result.success(resultError("发送失败", 3));
      } catch (IOException e) {
        result.success(resultError("发送失败", 3));
      }
    } else if (type == MessageContent.MessageType.MESSAGE_LOCATION) {
      float latitude = (float)argMap.get("latitude");
      float longitude = (float)argMap.get("longitude");
      String address = (String)argMap.get("address");
      Location loc = Location.newLocation(latitude, longitude);
      loc.address = address;
      if (TextUtils.isEmpty(loc.address)) {
        queryLocation(imsg);
      }
      _sendGroupMessage(imsg, result);
    } else {
      result.success(resultSuccess("暂不支持"));
    }
  }

  void _sendGroupMessage(IMessage imsg, final Result result) {
    imsg.timestamp = now();
    imsg.isOutgoing = true;
    saveMessage(imsg);
    loadUserName(imsg);
    GroupOutbox.getInstance().sendMessage(imsg);
    result.success(resultSuccess(convertToMap(imsg)));
    onNewGroupMessage(imsg, imsg.receiver);
  }
  private void getLocalCacheImage(Object arg, final Result result) {
    Map argMap = convertToMap(arg);
    String url = (String)argMap.get("url");

    String path;
    if (url.startsWith("file:")) {
//      url = url.replaceFirst("file:", "");
      path = url;
    } else {
       path = FileCache.getInstance().getCachedFilePath(url);
    }
    try {
      byte[] d = toByteArray(path);
      result.success(resultSuccess(d));
    }catch (Exception e) {
      result.success(resultSuccess(null));
    }
  }
  private void getLocalMediaURL(Object arg, final Result result) {
    Map argMap = convertToMap(arg);
    String url = (String)argMap.get("url");
    String path = FileCache.getInstance().getCachedFilePath(url);
    result.success(resultSuccess(path));
  }
  private void clearReadCount(Object arg, final Result result) {
    Map argMap = convertToMap(arg);
    String cid = (String)argMap.get("cid");
    long l_uid =0;
    try {
      l_uid = Long.parseLong(cid);

    } catch (Exception e) {
      result.success(resultError("clear fail", 1));
    }
    int pos = findConversationPosition(l_uid, Conversation.CONVERSATION_PEER);
    Conversation conversation = null;
    if (pos >= 0) {

      conversation = conversations.get(pos);
      conversation.setUnreadCount(0 );
      ConversationDB.getInstance().setNewCount(conversation.rowid,0);
      updateConversationDetail(conversation);

    }


    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "clearReadCountSuccess");
    this.callFlutter(resultSuccess(map));
  }
  private void clearGroupReadCount(Object arg, final Result result) {
    Map argMap = convertToMap(arg);
    String cid = (String)argMap.get("cid");
    long l_uid =0;
    try {
      l_uid = Long.parseLong(cid);

    } catch (Exception e) {
      result.success(resultError("clear fail", 1));
    }
    int pos = findConversationPosition(l_uid, Conversation.CONVERSATION_GROUP);
    Conversation conversation = null;
    if (pos >= 0) {

      conversation = conversations.get(pos);
      conversation.setUnreadCount(0 );
      ConversationDB.getInstance().setNewCount(conversation.rowid,0);
      updateConversationDetail(conversation);

    }


    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "clearReadCountSuccess");
    this.callFlutter(resultSuccess(map));
  }
  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    this.eventSink = events;
  }

  @Override
  public void onCancel(Object arguments) {
    this.eventSink = null;
  }

  /// helper
  private void openDB(long currentUID) {
    File p = context.getDir("db", Context.MODE_PRIVATE);
    File f = new File(p, String.format("gobelieve_%d.db", currentUID));
    String path = f.getPath();
    MessageDatabaseHelper dh = MessageDatabaseHelper.getInstance();
    dh.open(context.getApplicationContext(), path);
    SQLiteDatabase db = dh.getDatabase();
    PeerMessageDB.getInstance().setDb(db);
    EPeerMessageDB.getInstance().setDb(db);
    GroupMessageDB.getInstance().setDb(db);
    CustomerMessageDB.getInstance().setDb(db);
    ConversationDB.getInstance().setDb(db);
  }

  private static class LoginTread extends  Thread {
    String uid;

    String accessToken;
    Context context;

    LoginTread(String uid, Context context) {
      this.uid = uid;
      this.context = context;
    }

    @Override
    public void run() {
      String URL = "http://mm.3dsqq.com:8000";

      String uri = String.format("%s/v1/login/GetAuth", URL);
      try {
        HttpClient getClient = new DefaultHttpClient();
        HttpPost request = new HttpPost(uri);
        JSONObject json = new JSONObject();
        json.put("uid", uid);
        int PLATFORM_ANDROID = 2;
        String androidID = Secure.getString(context.getContentResolver(),
                ANDROID_ID);
        json.put("platform_id", PLATFORM_ANDROID);
        json.put("device_id", androidID);
        StringEntity s = new StringEntity(json.toString());
        s.setContentEncoding(new BasicHeader(HTTP.CONTENT_TYPE, "application/json"));
        request.setEntity(s);

        HttpResponse response = getClient.execute(request);
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != HttpStatus.SC_OK){
          System.out.println("login failure code is:"+statusCode);
          return;
        }
        int len = (int)response.getEntity().getContentLength();
        byte[] buf = new byte[len];
        InputStream inStream = response.getEntity().getContent();
        int pos = 0;
        while (pos < len) {
          int n = inStream.read(buf, pos, len - pos);
          if (n == -1) {
            break;
          }
          pos += n;
        }
        inStream.close();
        if (pos != len) {
          return;
        }
        String txt = new String(buf, "UTF-8");
        JSONObject jsonObject = new JSONObject(txt);
        accessToken = jsonObject.getJSONObject("data").getString("token");
      } catch (Exception e) {
        e.printStackTrace();
      }
    }

    public String getToken() {
      return accessToken;
    }
  }

  private String login(String uid) {
    LoginTread loginTread = new LoginTread(uid, context);
    loginTread.start();
    try {
      loginTread.join();
    } catch (Exception e) {
      e.printStackTrace();
    }
    return loginTread.getToken();
  }

  public void callFlutter(Object params) {
    if (this.eventSink != null) {
      this.eventSink.success(params);
    }
  }

  List<Object>convertToMapList(List<IMessage> objects) {
    return com.alibaba.fastjson.JSONArray.parseArray(com.alibaba.fastjson.JSONArray.toJSONString(objects));
  }

  List<Object> convertConversionToMapList(List<Conversation> objects) {
    return com.alibaba.fastjson.JSONArray.parseArray(com.alibaba.fastjson.JSONArray.toJSONString(objects));
  }

  Map<String, Object> convertToMap(Object obj) {
    return com.alibaba.fastjson.JSONObject.parseObject(com.alibaba.fastjson.JSONObject.toJSONString(obj));
  }

  //  OutboxObserver,
  public void onAudioUploadSuccess(IMessage msg, String url) {
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onAudioUploadSuccess");
    map.put("URL", url);
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  public void onAudioUploadFail(IMessage msg) {
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onAudioUploadFail");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  public void onImageUploadSuccess(IMessage msg, String url){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onImageUploadSuccess");
    map.put("URL", url);
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  public void onImageUploadFail(IMessage msg){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onImageUploadFail");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  public void onVideoUploadSuccess(IMessage msg, String url, String thumbURL){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onVideoUploadSuccess");
    map.put("URL", url);
    map.put("thumbnailURL", thumbURL);
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  public void onVideoUploadFail(IMessage msg){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onVideoUploadFail");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  public void onFileUploadSuccess(IMessage msg, String url){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onFileUploadSuccess");
    map.put("URL", url);
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }
  public void onFileUploadFail(IMessage msg){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onFileUploadFail");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  //  FileDownloader.FileDownloaderObserver,
  public void onFileDownloadSuccess(IMessage msg) {
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onFileDownloadSuccess");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }
  public void onFileDownloadFail(IMessage msg){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onFileDownloadFail");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  //  IMServiceObserver,
  public void onConnectState(IMService.ConnectState state) {
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onConnectState");
    map.put("result", state.ordinal());
    this.callFlutter(resultSuccess(map));
  }

  //  PeerMessageObserver
  public void onPeerMessage(IMMessage msg) {
    final IMessage imsg = new IMessage();
    imsg.timestamp = msg.timestamp;
    imsg.msgLocalID = msg.msgLocalID;
    imsg.sender = msg.sender;
    imsg.receiver = msg.receiver;
    imsg.setContent(msg.content);
    imsg.isOutgoing = (msg.sender == this.currentUID);
    if (imsg.isOutgoing) {
      imsg.flags |= MessageFlag.MESSAGE_FLAG_ACK;
    }

    loadUserName(imsg);
    downloadMessageContent(imsg);
    updateNotificationDesc(imsg);

    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onPeerMessage");
    map.put("result", convertToMap(imsg));
    this.callFlutter(resultSuccess(map));

    long cid = 0;
    if (msg.sender == this.currentUID) {
      cid = msg.receiver;
    } else {
      cid = msg.sender;
    }
    onNewMessage(imsg, cid);
  }

  public void onPeerSecretMessage(IMMessage msg) {
    final IMessage imsg = new IMessage();
    imsg.timestamp = msg.timestamp;
    imsg.msgLocalID = msg.msgLocalID;
    imsg.sender = msg.sender;
    imsg.receiver = msg.receiver;
    imsg.secret = true;
    imsg.setContent(msg.content);
    imsg.isOutgoing = (msg.sender == this.currentUID);
    if (imsg.isOutgoing) {
      imsg.flags |= MessageFlag.MESSAGE_FLAG_ACK;
    }
    loadUserName(imsg);
    downloadMessageContent(imsg);
    updateNotificationDesc(imsg);
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onPeerSecretMessage");
    map.put("result", convertToMap(imsg));
    this.callFlutter(resultSuccess(map));

    long cid = 0;
    if (msg.sender == this.currentUID) {
      cid = msg.receiver;
    } else {
      cid = msg.sender;
    }
    onNewMessage(imsg, cid);
  }

  private void onNewMessage(IMessage imsg, long cid) {
    int pos = findConversationPosition(cid, Conversation.CONVERSATION_PEER);
    Conversation conversation = null;
    if (pos == -1) {
      conversation = newPeerConversation(cid);
    } else {
      conversation = conversations.get(pos);
    }
    conversation.message = imsg;
    if (currentUID == imsg.receiver) {
      //conversation.setUnreadCount(conversation.getUnreadCount());
      ConversationDB.getInstance().setNewCount(conversation.rowid,conversation.getUnreadCount() + 1);
    }
    updateConversationDetail(conversation);
    if (pos == -1) {
      conversations.add(0, conversation);
    } else if (pos > 0) {
      conversations.remove(pos);
      conversations.add(0, conversation);
    } else {
      //pos == 0
    }
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onNewMessage");
    this.callFlutter(resultSuccess(map));
  }


  public void onPeerMessageACK(IMMessage msg, int error){

    long msgLocalID = msg.msgLocalID;
    long uid = msg.receiver;
    if (msgLocalID == 0) {
      MessageContent c = IMessage.fromRaw(msg.plainContent);
      if (c.getType() == MessageContent.MessageType.MESSAGE_REVOKE) {
        Revoke r = (Revoke)c;
        int pos = -1;
        if (!msg.secret) {
          pos = findConversationPosition(uid, Conversation.CONVERSATION_PEER);
        } else {
          pos = findConversationPosition(uid, Conversation.CONVERSATION_PEER_SECRET);
        }
        Conversation conversation = conversations.get(pos);
        if (r.msgid.equals(conversation.message.getUUID())) {
          conversation.message.setContent(r);
          updateConvNotificationDesc(conversation);
          updateConversationDetail(conversation);
        }
      }
    }

    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onPeerMessageACK");
    map.put("error", error);
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));

  }
  public void onPeerMessageFailure(IMMessage msg){
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onPeerMessageFailure");
    map.put("result", convertToMap(msg));
    this.callFlutter(resultSuccess(map));
  }

  // GroupMessageObserver

  @Override
  public void onGroupMessages(List<IMMessage> msgs) {
    for (IMMessage msg : msgs) {
      if (msg.isGroupNotification) {
        assert(msg.sender == 0);
        this.onGroupNotification(msg.content);
      } else {
        this.onGroupMessage(msg);
      }
    }

  }

  public void onGroupMessage(IMMessage msg) {
    if (msg.receiver != groupID) {
      //return;
    }
    //Log.i(TAG, "recv msg:" + msg.content);
    final IMessage imsg = new IMessage();
    imsg.timestamp = msg.timestamp;
    imsg.msgLocalID = msg.msgLocalID;
    imsg.sender = msg.sender;
    imsg.receiver = msg.receiver;
    imsg.setContent(msg.content);
    imsg.isOutgoing = (msg.sender == this.currentUID);
    if (imsg.isOutgoing) {
      imsg.flags |= MessageFlag.MESSAGE_FLAG_ACK;
    }

    IMessage mm = findMessage(imsg.getUUID());
    if (mm != null) {
      //Log.i(TAG, "receive repeat message:" + imsg.getUUID());
      if (imsg.isOutgoing) {
        int flags = imsg.flags;
        flags = flags & ~MessageFlag.MESSAGE_FLAG_FAILURE;
        flags = flags | MessageFlag.MESSAGE_FLAG_ACK;
        mm.setFlags(flags);
      }
      return;
    }

    if (msg.isSelf) {
      return;
    }

    loadUserName(imsg);

    downloadMessageContent(imsg);
    updateNotificationDesc(imsg);
    if (imsg.getType() == MessageContent.MessageType.MESSAGE_REVOKE) {
      Revoke revoke = (Revoke)imsg.content;
      IMessage m = findMessage(revoke.msgid);
      if (m != null) {
        replaceMessage(m, imsg);
      }
    } else {
      insertMessage(imsg);
    }
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onGroupMessage");
    map.put("result", convertToMap(imsg));
    this.callFlutter(resultSuccess(map));

    long cid = 0;
    ///if (msg.sender == this.currentUID) {
    cid = msg.receiver;
    //} else {
    //  cid = msg.sender;
    //}
    onNewGroupMessage(imsg, cid);
  }
  private void onNewGroupMessage(IMessage imsg, long cid) {
    int pos = findConversationPosition(cid, Conversation.CONVERSATION_GROUP);
    Conversation conversation = null;
    if (pos == -1) {
      conversation = newGroupConversation(cid);
    } else {
      conversation = conversations.get(pos);
    }
    conversation.message = imsg;
    if (currentUID != imsg.sender) {
      //conversation.setUnreadCount(conversation.getUnreadCount());
      ConversationDB.getInstance().setNewCount(conversation.rowid,conversation.getUnreadCount() + 1);
    }
    updateConversationDetail(conversation);
    if (pos == -1) {
      conversations.add(0, conversation);
    } else if (pos > 0) {
      conversations.remove(pos);
      conversations.add(0, conversation);
    } else {
      //pos == 0
    }
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onNewGroupMessage");
    this.callFlutter(resultSuccess(map));
  }
  @Override
  public void onGroupMessageACK(IMMessage im, int error) {
    long msgLocalID = im.msgLocalID;
    long gid = im.receiver;
    if (gid != groupID) {
      return;
    }
    //Log.i(TAG, "message ack");

    if (error == MessageACK.MESSAGE_ACK_SUCCESS) {
      if (msgLocalID > 0) {
        IMessage imsg = findMessage(msgLocalID);
        if (imsg == null) {
          //Log.i(TAG, "can't find msg:" + msgLocalID);
          return;
        }
        imsg.setAck(true);
      } else {
        MessageContent c = IMessage.fromRaw(im.content);
        if (c.getType() == MessageContent.MessageType.MESSAGE_REVOKE) {
          Revoke r = (Revoke) c;
          IMessage imsg = findMessage(r.msgid);
          if (imsg == null) {
            //Log.i(TAG, "can't find msg:" + msgLocalID);
            return;
          }
          imsg.setContent(r);
          updateNotificationDesc(imsg);
          //adapter.notifyDataSetChanged();
        }
      }
    } else {
      if (msgLocalID > 0) {
        IMessage imsg = findMessage(msgLocalID);
        if (imsg == null) {
         // Log.i(TAG, "can't find msg:" + msgLocalID);
          return;
        }
        imsg.setFailure(true);
      } else {
        MessageContent c = IMessage.fromRaw(im.content);
        if (c.getType() == MessageContent.MessageType.MESSAGE_REVOKE) {
          //Toast.makeText(this, "撤回失败", Toast.LENGTH_SHORT).show();
        }
      }
    }
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onGroupMessageACK");
    this.callFlutter(resultSuccess(map));
  }

  @Override
  public void onGroupMessageFailure(IMMessage im) {
    long msgLocalID = im.msgLocalID;
    long gid = im.receiver;
    if (gid != groupID) {
      return;
    }
   // Log.i(TAG, "message failure");

    if (msgLocalID > 0) {
      IMessage imsg = findMessage(msgLocalID);
      if (imsg == null) {
        //Log.i(TAG, "can't find msg:" + msgLocalID);
        return;
      }
      imsg.setFailure(true);
    } else {
      MessageContent c = IMessage.fromRaw(im.content);
      if (c.getType() == MessageContent.MessageType.MESSAGE_REVOKE) {
        //Toast.makeText(this, "撤回失败", Toast.LENGTH_SHORT).show();
      }
    }
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onGroupMessageFailure");
    this.callFlutter(resultSuccess(map));
  }
  public void onGroupNotification(String text) {
    GroupNotification notification = GroupNotification.newGroupNotification(text);

    if (notification.groupID != groupID) {
      //return;
    }

    IMessage imsg = new IMessage();
    imsg.sender = 0;
    imsg.receiver = groupID;
    imsg.timestamp = notification.timestamp;
    imsg.setContent(notification);

    updateNotificationDesc(imsg);

    if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_NAME_UPDATED) {
      this.groupName = notification.groupName;
      //getSupportActionBar().setTitle(groupName);
    }
    insertMessage(imsg);
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("result", convertToMap(imsg));
    map.put("type", "onGroupNotification");
    this.callFlutter(resultSuccess(map));
  }


  protected IMessage findMessage(long msgLocalID) {
    for (IMessage imsg : messages) {
      if (imsg.msgLocalID == msgLocalID) {
        return imsg;
      }
    }
    return null;
  }

  protected IMessage findMessage(String uuid) {
    if (TextUtils.isEmpty(uuid)) {
      return null;
    }
    for (IMessage imsg : messages) {
      if (imsg.getUUID().equals(uuid)) {
        return imsg;
      }
    }
    return null;
  }


  protected void deleteMessage(IMessage imsg) {
    int index = -1;
    for (int i = 0; i < messages.size(); i++) {
      IMessage m = messages.get(i);
      if (m.msgLocalID == imsg.msgLocalID) {
        index = i;
        break;
      }
    }
    if (index != -1) {
      messages.remove(index);
    }
  }

  protected void replaceMessage(IMessage imsg, IMessage other) {
    int index = -1;
    for (int i = 0; i < messages.size(); i++) {
      IMessage m = messages.get(i);
      if (m.msgLocalID == imsg.msgLocalID) {
        index = i;
        break;
      }
    }
    if (index != -1) {
      messages.set(index, other);
    }
  }

  protected void insertMessage(IMessage imsg) {
    IMessage lastMsg = null;
    if (messages.size() > 0) {
      lastMsg = messages.get(messages.size() - 1);
    }
    //间隔10分钟，添加时间分割线
    if (lastMsg == null || imsg.timestamp - lastMsg.timestamp > 10*60) {
      TimeBase timeBase = TimeBase.newTimeBase(imsg.timestamp);
      String s = TimeUtil.formatTimeBase(timeBase.timestamp);
      timeBase.description = s;
      IMessage t = new IMessage();
      t.content = timeBase;
      t.timestamp = imsg.timestamp;
      messages.add(t);
    }

    checkAtName(imsg);
    messages.add(imsg);
  }
  // SystemMessageObserver
  @Override
  public void onSystemMessage(String sm) {
    Map<String, Object> map = new HashMap<String, Object>();
    map.put("type", "onSystemMessage");
    map.put("result", sm);
    this.callFlutter(resultSuccess(map));
  }

  Object resultSuccess(Object data) {
    return _buildResult(0, "成功", data);
  }

  Object resultError(String error, int code) {
    return _buildResult(code, error, null);
  }

  Object _buildResult(int code, String message, Object data) {
    Map<String, Object> hashMap = new HashMap<String, Object>();
    hashMap.put("code", code);
    hashMap.put("message", message);
    hashMap.put("data", data);
    return hashMap;
  }

  private void refreshHost(String imHost, String apiHost) {
    new MyTask().execute(new MyTaskParams(imHost, apiHost));
  }

  private static class MyTaskParams {
    String imHost;
    String apiHost;
    MyTaskParams(String imHost, String apiHost) {
      this.imHost = imHost;
      this.apiHost = apiHost;
    }
  }

  private class MyTask extends AsyncTask<MyTaskParams, Integer, Integer> {
    @Override
    protected Integer doInBackground(MyTaskParams... urls) {
      for (int i = 0; i < 10; i++) {
        String imHost = lookupHost(urls[0].imHost);
        String apiHost = lookupHost(urls[0].apiHost);
        if (TextUtils.isEmpty(imHost) || TextUtils.isEmpty(apiHost)) {
          try {
            Thread.sleep(1000 * 1);
          } catch (InterruptedException e) {
          }
          continue;
        } else {
          break;
        }
      }
      return 0;
    }

    private String lookupHost(String host) {
      try {
        InetAddress inetAddress = InetAddress.getByName(host);
        return inetAddress.getHostAddress();
      } catch (UnknownHostException exception) {
        exception.printStackTrace();
        return "";
      }
    }
  }

  public boolean isAppOnForeground() {
    // Returns a list of application processes that are running on the
    // device
    ActivityManager activityManager =
            (ActivityManager) context.getApplicationContext().getSystemService(
                    Context.ACTIVITY_SERVICE);
    String packageName = context.getApplicationContext().getPackageName();

    List<ActivityManager.RunningAppProcessInfo> appProcesses = activityManager
            .getRunningAppProcesses();
    if (appProcesses == null)
      return false;

    for (ActivityManager.RunningAppProcessInfo appProcess : appProcesses) {
      // The name of the process that this object is associated with.
      if (appProcess.processName.equals(packageName)
              && appProcess.importance
              == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
        return true;
      }
    }
    return false;
  }

  public static class User {
    public long uid;
    public String name;
    public String avatarURL;

    //name为nil时，界面显示identifier字段
    public String identifier;
  }

  public interface GetUserCallback {
    void onUser(User u);
  }

  //加载消息发送者的名称和头像信息
  protected void loadUserName(IMessage msg) {
    if (msg.sender == 0) {
      return;
    }
    User u = getUser(msg.sender);
    msg.setSenderAvatar(u.avatarURL);
    if (TextUtils.isEmpty(u.name)) {
      msg.setSenderName(u.identifier);
      final IMessage fmsg = msg;
      asyncGetUser(msg.sender, new GetUserCallback() {
        @Override
        public void onUser(User u) {
          fmsg.setSenderName(u.name);
          fmsg.setSenderAvatar(u.avatarURL);
        }
      });
    } else {
      msg.setSenderName(u.name);
    }
  }

  protected User getUser(long uid) {
    User u = new User();
    u.uid = uid;
    u.name = null;
    u.avatarURL = "";
    u.identifier = String.format("%d", uid);
    return u;
  }

  protected void asyncGetUser(long uid, GetUserCallback cb) {

  }

  protected void downloadMessageContent(IMessage msg) {
    if (msg.content.getType() == MessageContent.MessageType.MESSAGE_AUDIO) {
      Audio audio = (Audio) msg.content;
      FileDownloader downloader = FileDownloader.getInstance();
      if (!FileCache.getInstance().isCached(audio.url) && !downloader.isDownloading(msg)) {
        downloader.download(msg);
      }
      msg.setDownloading(downloader.isDownloading(msg));
    } else if (msg.content.getType() == MessageContent.MessageType.MESSAGE_IMAGE) {
      Image image = (Image)msg.content;
      FileDownloader downloader = FileDownloader.getInstance();
      //加密的图片消息需要手动下载后解密
      if (msg.secret && !image.url.startsWith("file:") &&
              !FileCache.getInstance().isCached(image.url) &&
              !downloader.isDownloading(msg)) {
        downloader.download(msg);
      }
      msg.setDownloading(downloader.isDownloading(msg));
    } else if (msg.content.getType() == MessageContent.MessageType.MESSAGE_LOCATION) {
      Location loc = (Location)msg.content;
      if (TextUtils.isEmpty(loc.address)) {
        queryLocation(msg);
      }
    } else if (msg.content.getType() == MessageContent.MessageType.MESSAGE_VIDEO) {
      Video video = (Video)msg.content;
      FileDownloader downloader = FileDownloader.getInstance();
      //加密的图片消息需要手动下载后解密
      if (msg.secret && !video.thumbnail.startsWith("file:") &&
              !FileCache.getInstance().isCached(video.thumbnail) &&
              !downloader.isDownloading(msg)) {
        downloader.download(msg);
      }
      msg.setDownloading(downloader.isDownloading(msg));
    }
  }

  protected void queryLocation(final IMessage msg) {
//    final Location loc = (Location)msg.content;
//
//    msg.setGeocoding(true);
//    // 第一个参数表示一个Latlng，第二参数表示范围多少米，第三个参数表示是火系坐标系还是GPS原生坐标系
//    RegeocodeQuery query = new RegeocodeQuery(new LatLonPoint(loc.latitude, loc.longitude), 200, GeocodeSearch.AMAP);
//
//    GeocodeSearch mGeocodeSearch = new GeocodeSearch(this.context);
//    mGeocodeSearch.setOnGeocodeSearchListener(new GeocodeSearch.OnGeocodeSearchListener() {
//      @Override
//      public void onRegeocodeSearched(RegeocodeResult regeocodeResult, int i) {
//        if (i == 0 && regeocodeResult != null && regeocodeResult.getRegeocodeAddress() != null
//                && regeocodeResult.getRegeocodeAddress().getFormatAddress() != null) {
//          String address = regeocodeResult.getRegeocodeAddress().getFormatAddress();
//          loc.address = address;
//          saveMessageAttachment(msg, address);
//        } else {
//          // 定位失败;
//        }
//        msg.setGeocoding(false);
//      }
//
//      @Override
//      public void onGeocodeSearched(GeocodeResult geocodeResult, int i) {
//
//      }
//    });
//
//    mGeocodeSearch.getFromLocationAsyn(query);// 设置同步逆地理编码请求
  }

  protected void updateNotificationDesc(IMessage imsg) {
    if (imsg.getType() == MessageContent.MessageType.MESSAGE_REVOKE) {
      Revoke revoke = (Revoke)imsg.content;
      if (imsg.isOutgoing) {
        revoke.description = context.getString(R.string.message_revoked, context.getString(R.string.you));
      } else {
        User u = this.getUser(imsg.sender);
        String name = !TextUtils.isEmpty(u.name) ? u.name : u.identifier;
        revoke.description = context.getString(R.string.message_revoked, name);
      }
    } else if (imsg.getType() == MessageContent.MessageType.MESSAGE_ACK) {
      ACK ack = (ACK)imsg.content;
      if (ack.error == MessageACK.MESSAGE_ACK_NOT_YOUR_FRIEND) {
        ack.description = context.getString(R.string.message_not_friend);
      } else if (ack.error == MessageACK.MESSAGE_ACK_IN_YOUR_BLACKLIST) {
        ack.description = context.getString(R.string.message_refuesed);
      } else if (ack.error == MessageACK.MESSAGE_ACK_NOT_MY_FRIEND) {
        ack.description = context.getString(R.string.message_not_my_friend);
      }
    }
  }

  protected void saveMessageAttachment(IMessage msg, String address) {
    this.messageDB.saveMessageAttachment(msg, address);
  }

  protected void saveMessage(IMessage imsg) {


    this.messageDB.saveMessage(imsg);
  }

  protected void removeMessage(IMessage imsg) {
    this.messageDB.removeMessage(imsg);
  }

  protected void markMessageListened(IMessage imsg) {
    this.messageDB.markMessageListened(imsg);
  }

  protected void markMessageFailure(IMessage imsg) {
    this.messageDB.markMessageFailure(imsg);
  }

  protected void eraseMessageFailure(IMessage imsg) {
    this.messageDB.eraseMessageFailure(imsg);
  }

  void wrapperMessages(List<IMessage> messages) {
    int count = messages.size();
    prepareMessage(messages, count);
  }

  protected void prepareMessage(List<IMessage> messages, int count) {
    for (int i = 0; i < count; i++) {
      IMessage msg = messages.get(i);
      prepareMessage(msg);
    }
  }

  protected void prepareMessage(IMessage message) {
    loadUserName(message);
    downloadMessageContent(message);
    updateNotificationDesc(message);
    checkMessageFailureFlag(message);
    checkAtName(message);
    sendReaded(message);
  }

  protected void checkAtName(IMessage message) {

  }
  protected void sendReaded(IMessage message) {

  }

  void checkMessageFailureFlag(IMessage msg) {
    if (msg.isOutgoing) {
      if (msg.timestamp < uptime && !msg.isAck()) {
        msg.setFailure(true);
        markMessageFailure(msg);
      }
    }
  }

  //app 启动时间戳，app启动时初始化
  public static int uptime;
  static {
    uptime = now();
  }

  public static int now() {
    Date date = new Date();
    long t = date.getTime();
    return (int)(t/1000);
  }

  protected MessageIterator createMessageIterator() {
    MessageIterator iter = messageDB.newMessageIterator(conversationID);
    return iter;
  }

  protected int pageSize = 20;

  private List<IMessage> loadConversationData() {
    ArrayList<IMessage> messages = new ArrayList<IMessage>();
    int count = 0;
    MessageIterator iter = createMessageIterator();
    while (iter != null) {
      IMessage msg = iter.next();
      if (msg == null) {
        break;
      }

      msg.isOutgoing = (msg.sender == currentUID);
      messages.add(0, msg);
      if (++count >= pageSize) {
        break;
      }
    }
    return messages;
  }

  private List<IMessage> loadConversationData(long messageID) {
    HashSet<String> uuidSet = new HashSet<String>();
    ArrayList<IMessage> messages = new ArrayList<IMessage>();

    int count = 0;
    MessageIterator iter;

    iter = createMiddleMessageIterator(messageID);

    while (iter != null) {
      IMessage msg = iter.next();
      if (msg == null) {
        break;
      }

      //不加载重复的消息
      if (!TextUtils.isEmpty(msg.getUUID()) && uuidSet.contains(msg.getUUID())) {
        continue;
      }

      if (!TextUtils.isEmpty(msg.getUUID())) {
        uuidSet.add(msg.getUUID());
      }
      msg.isOutgoing = (msg.sender == currentUID);
      messages.add(0, msg);
      if (++count >= pageSize*2) {
        break;
      }
    }

    return messages;
  }

  protected MessageIterator createMiddleMessageIterator(long messageID) {
    MessageIterator iter = messageDB.newMiddleMessageIterator(conversationID, messageID);
    return iter;
  }

  protected MessageIterator createForwardMessageIterator(long messageID) {
    MessageIterator iter = messageDB.newForwardMessageIterator(conversationID, messageID);
    return iter;
  }

  protected MessageIterator createBackwardMessageIterator(long messageID) {
    MessageIterator iter = messageDB.newBackwardMessageIterator(conversationID, messageID);
    return iter;
  }

  MessageContent.MessageType _getMessageTypeFromNumber(int number) {
    switch (number) {
      case 1:
        return MessageContent.MessageType.MESSAGE_TEXT;
      case 2:
        return MessageContent.MessageType.MESSAGE_IMAGE;
      case 3:
        return MessageContent.MessageType.MESSAGE_AUDIO;
      case 4:
        return MessageContent.MessageType.MESSAGE_LOCATION;
      case 5:
        return MessageContent.MessageType.MESSAGE_GROUP_NOTIFICATION; // 群通知
      case 6:
        return MessageContent.MessageType.MESSAGE_LINK;
      case 7:
        return MessageContent.MessageType.MESSAGE_HEADLINE; // 客服标题
      case 8:
        return MessageContent.MessageType.MESSAGE_VOIP;
      case 9:
        return MessageContent.MessageType.MESSAGE_GROUP_VOIP;
      case 10:
        return MessageContent.MessageType.MESSAGE_P2P_SESSION;
      case 11:
        return MessageContent.MessageType.MESSAGE_SECRET;
      case 12:
        return MessageContent.MessageType.MESSAGE_VIDEO;
      case 13:
        return MessageContent.MessageType.MESSAGE_FILE;
      case 14:
        return MessageContent.MessageType.MESSAGE_REVOKE;
      case 15:
        return MessageContent.MessageType.MESSAGE_ACK;
      case 16:
        return MessageContent.MessageType.MESSAGE_CLASSROOM; // 群课堂
      case 254:
        return MessageContent.MessageType.MESSAGE_TIME_BASE; // 虚拟的消息，不会存入磁盘
      case 255:
        return MessageContent.MessageType.MESSAGE_ATTACHMENT;
      default:
        return MessageContent.MessageType.MESSAGE_UNKNOWN;
    }
  }

  protected String localImageURL() {
    UUID uuid = UUID.randomUUID();
    return "http://localhost/images/"+ uuid.toString() + ".png";
  }
  protected String localVideoURL() {
    UUID uuid = UUID.randomUUID();
    return "http://localhost/videos/"+ uuid.toString() + ".mp4";
  }
  protected String localFileURL(String ext) {
    UUID uuid = UUID.randomUUID();
    return "http://localhost/videos/"+ uuid.toString() + ext;
  }
  protected String localAudioURL() {
    UUID uuid = UUID.randomUUID();
    return "http://localhost/audios/" + uuid.toString() + ".amr";
  }

  /**
   * the traditional io way
   *
   * @param filename
   * @return
   * @throws IOException
   */
  public static byte[] toByteArray(String filename) throws IOException {

    File f = null;
    try {
      f = new File(new URI(filename).getPath());
    } catch (URISyntaxException e) {
      e.printStackTrace();
    }
    if (!f.exists()) {
      throw new FileNotFoundException(filename);
    }

    ByteArrayOutputStream bos = new ByteArrayOutputStream((int) f.length());
    BufferedInputStream in = null;
    try {
      in = new BufferedInputStream(new FileInputStream(f));
      int buf_size = 1024;
      byte[] buffer = new byte[buf_size];
      int len = 0;
      while (-1 != (len = in.read(buffer, 0, buf_size))) {
        bos.write(buffer, 0, len);
      }
      return bos.toByteArray();
    } catch (IOException e) {
      e.printStackTrace();
      throw e;
    } finally {
      try {
        in.close();
      } catch (IOException e) {
        e.printStackTrace();
      }
      bos.close();
    }
  }

  public  String messageContentToString(MessageContent content) {
    if (content instanceof Text) {
      return ((Text) content).text;
    } else if (content instanceof Image) {
      return "一张图片";
    } else if (content instanceof Audio) {
      return "一段语音";
    } else if (content instanceof com.beetle.bauhinia.db.message.File) {
      return "一个文件";
    } else if (content instanceof Video) {
      return "一个视频";
    } else if (content instanceof com.beetle.bauhinia.db.message.Notification) {
      return ((com.beetle.bauhinia.db.message.Notification) content).description;
    } else if (content instanceof Location) {
      return "一个地理位置";
    } else if (content instanceof GroupVOIP) {
      return ((GroupVOIP) content).description;
    } else if (content instanceof VOIP) {
      VOIP voip = (VOIP) content;
      if (voip.videoEnabled) {
        return "视频聊天";
      } else {
        return "语音聊天";
      }
    } else if (content instanceof Secret) {
      return "消息未能解密";
    } else if (content instanceof P2PSession) {
      return "";
    } else {
      return "未知的消息类型";
    }
  }

  void updateConversationDetail(Conversation conv) {
    if (conv !=null){
      if (conv.message !=null) {
        MessageContent content = conv.message.content;
        String detail = messageContentToString(content);
        conv.setDetail(detail);
      }
    }
  }

  private void updateConvNotificationDesc(Conversation conv) {
    final IMessage imsg = conv.message;
    if (imsg == null || imsg.content.getType() != MessageContent.MessageType.MESSAGE_GROUP_NOTIFICATION) {
      return;
    }
    long currentUID = this.currentUID;
    GroupNotification notification = (GroupNotification)imsg.content;
    if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_CREATED) {
      if (notification.master == currentUID) {
        notification.description = String.format("您创建了\"%s\"群组", notification.groupName);
      } else {
        notification.description = String.format("您加入了\"%s\"群组", notification.groupName);
      }
    } else if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_DISBAND) {
      notification.description = "群组已解散";
    } else if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_MEMBER_ADDED) {
      User u = getUser(notification.member);
      if (TextUtils.isEmpty(u.name)) {
        notification.description = String.format("\"%s\"加入群", u.identifier);
        final GroupNotification fnotification = notification;
        final Conversation fconv = conv;
        asyncGetUser(notification.member, new GetUserCallback() {
          @Override
          public void onUser(User u) {
            fnotification.description = String.format("\"%s\"加入群", u.name);
            if (fconv.message == imsg) {
              fconv.setDetail(fnotification.description);
            }
          }
        });
      } else {
        notification.description = String.format("\"%s\"加入群", u.name);
      }
    } else if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_MEMBER_LEAVED) {
      User u = getUser(notification.member);
      if (TextUtils.isEmpty(u.name)) {
        notification.description = String.format("\"%s\"离开群", u.identifier);
        final GroupNotification fnotification = notification;
        final Conversation fconv = conv;
        asyncGetUser(notification.member, new GetUserCallback() {
          @Override
          public void onUser(User u) {
            fnotification.description = String.format("\"%s\"离开群", u.name);
            if (fconv.message == imsg) {
              fconv.setDetail(fnotification.description);
            }
          }
        });
      } else {
        notification.description = String.format("\"%s\"离开群", u.name);
      }
    } else if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_NAME_UPDATED) {
      notification.description = String.format("群组改名为\"%s\"", notification.groupName);
    }else if (notification.notificationType == GroupNotification.NOTIFICATION_GROUP_MEMBER_MUTE) {
      User u = getUser(notification.member);
      if (TextUtils.isEmpty(u.name)) {
        if(notification.mute ==0){
          notification.description = String.format("\"%s\"被管理员解除禁言", u.identifier);
        }else{
          notification.description = String.format("\"%s\"被管理员禁言", u.identifier);
        }

        final GroupNotification fnotification = notification;
        final Conversation fconv = conv;
        asyncGetUser(notification.member, new GetUserCallback() {
          @Override
          public void onUser(User u) {
            GroupNotification notifications = (GroupNotification)imsg.content;
            if(notifications.mute ==0){
              fnotification.description = String.format("\"%s\"被管理员解除禁言", u.name);
            }else{
              fnotification.description = String.format("\"%s\"被管理员禁言", u.name);

            }
            if (fconv.message == imsg) {
              fconv.setDetail(fnotification.description);
            }
          }
        });
      } else {
        if(notification.mute ==0){
          notification.description = String.format("\"%s\"被管理员解除禁言", u.name);
        }else{
          notification.description = String.format("\"%s\"被管理员禁言", u.name);
        }

      }
    }
  }

  void updatePeerConversationName(Conversation conv) {
    User u = getUser(conv.cid);
    if (TextUtils.isEmpty(u.name)) {
      conv.setName(u.identifier);
      final Conversation fconv = conv;
      asyncGetUser(conv.cid, new GetUserCallback() {
        @Override
        public void onUser(User u) {
          fconv.setName(u.name);
          fconv.setAvatar(u.avatarURL);
        }
      });
    } else {
      conv.setName(u.name);
    }
    conv.setAvatar(u.avatarURL);
  }

  void updateGroupConversationName(Conversation conv) {
//    Group g = getGroup(conv.cid);
//    if (TextUtils.isEmpty(g.name)) {
//      conv.setName(g.identifier);
//      final Conversation fconv = conv;
//      asyncGetGroup(conv.cid, new GetGroupCallback() {
//        @Override
//        public void onGroup(Group g) {
//          fconv.setName(g.name);
//          fconv.setAvatar(g.avatarURL);
//        }
//      });
//    } else {
//      conv.setName(g.name);
//    }
//    conv.setAvatar(g.avatarURL);
  }

  public Conversation findConversation(long cid, int type) {
    for (int i = 0; i < conversations.size(); i++) {
      Conversation conv = conversations.get(i);
      if (conv.cid == cid && conv.type == type) {
        return conv;
      }
    }
    return null;
  }

  public int findConversationPosition(long cid, int type) {
    for (int i = 0; i < conversations.size(); i++) {
      Conversation conv = conversations.get(i);
      if (conv.cid == cid && conv.type == type) {
        return i;
      }
    }
    return -1;
  }

  public Conversation newPeerConversation(long cid) {
    Conversation conversation = new Conversation();
    conversation.type = Conversation.CONVERSATION_PEER;
    conversation.cid = cid;
    updatePeerConversationName(conversation);
    ConversationDB.getInstance().addConversation(conversation);
    return conversation;
  }

  public Conversation newGroupConversation(long cid) {
    Conversation conversation = new Conversation();
    conversation.type = Conversation.CONVERSATION_GROUP;
    conversation.cid = cid;
    updateGroupConversationName(conversation);
    ConversationDB.getInstance().addConversation(conversation);
    return conversation;
  }
}
