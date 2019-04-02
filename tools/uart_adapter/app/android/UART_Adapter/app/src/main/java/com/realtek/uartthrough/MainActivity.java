package com.realtek.uartthrough;




import java.net.InetAddress;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Semaphore;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import android.os.Looper;
import android.os.StrictMode;
import android.view.ViewConfiguration;
import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.app.ActionBar.LayoutParams;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.ClipData;
import android.content.ClipDescription;
import android.content.DialogInterface;
import android.content.Intent;
import android.util.Log;
import android.view.DragEvent;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.Window;
import android.view.WindowManager;
import android.view.View.DragShadowBuilder;
import android.view.View.OnClickListener;
import android.view.View.OnDragListener;
import android.view.View.OnTouchListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.AdapterView.OnItemLongClickListener;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.GridView;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.SimpleAdapter;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.realtek.uartthrough.MainActivity;
import com.realtek.uartthrough.R;
import com.realtek.uartthrough.MainActivity.DeviceDragListener;
import com.realtek.uartthrough.DeviceManager.DeviceInfo;

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class MainActivity extends Activity {
	private final Lock _mutex = new ReentrantLock(true);
	private Semaphore semaphore = new Semaphore(1, true);
	//TAG
	private final String TAG = "<uartthrough>";
	private final String TAG_DISCOVER = "Discovery";
	private final String TAG_UI_THREAD = "Update Ui thread";
	private byte[] lastTx = null;

	//Number
	public final int DEVICE_MAX_NUM = 32;
	public int DEVICE_CURRENT_NUM = -1;
	private boolean rcvThreadExit = false;
	private int isWaitUpdateCacheCount = 0;
	private int mPosition = -1;
	private int btn_height = 0;
	//UI Layout
	//private TextView		text_debug;
	private ImageButton btn_scanDevices;
	private ImageButton btn_setting;
	private ProgressDialog pd;
	private ProgressDialog cont_pd;
	private GridView gridView;
	private int draggedIndex = -1;
	private int mindexSelected = -1;
	private int mDraggedIndex = -1;
	private int mGroupID = -1;
	private int moveCount = 0;
	static boolean isWaitUpdate = false;
	private String selectedItemName = "";
	private String dropItemName = "";
	private final String IMAGEVIEW_TAG = "UartThrough";
	public static final int deviceNumberMax = 128;
	public static final int groupNumberMax = 16;
	boolean task_updateMDNS_enable = false;
	boolean isTIPEnd = false;
	boolean actionUP = false;
	String listSelectedGroupName = null;
	String listSelectedGroupID = null;
	View itemDragView[] = null;
	String arrayGroupID[] = null;
	public static DeviceInfo[] configuredDevices;
	public static DeviceInfo[] settingListdDevices;
	DeviceInfo SelectedDeviceInfo = new DeviceInfo();
	DeviceInfo[] attachedDeviceInfo;
	//UI Variable
	private SimpleAdapter adapter_deviceInfo = null;
	private SimpleAdapter adapter_deviceInfo_setting = null;
    private boolean popMenushow = false;
	int[] location = new int[2];
	Button btnSetting;
	//Variable
	public static DeviceInfo[] infoDevices;
	public static Globals_d g_d = Globals_d.getInstance();
	public int deviceNumberNow = 0;

	private Globals_ctrl g_ctrl = Globals_ctrl.getInstance();
	private boolean g_discoverEnable = false;
	private List<HashMap<String, Object>> devInfoList = new ArrayList<HashMap<String, Object>>();
	private NsdCore mNSD;
	private String recvBuf = "";

	//Thread
	private UpdateUiThread uiThread;
	private recvThread rcvThread = null;
	private final Lock _gmutex_recvBuf = new ReentrantLock(true);
	private PopupWindow popupMenu=null;

	//TcpClient
	private TcpClient dataClient;
	private TcpClient ctrlClient;
	private TcpClient dstCtrlClient;
	private boolean isMoved;
	private static final int TOUCH_SLOP = 40;
	private static Runnable mLongPressRunnable;
	private int mLastMotionX, mLastMotionY;
	//serial port Setting
	byte[] cmdPrefix = new byte[]{0x41, 0x4D, 0x45, 0x42, 0x41, 0x5F, 0x55, 0x41, 0x52, 0x54};
	String setting_rate = "";
	String setting_data = "";
	String setting_parity = "";
	String setting_stopbit = "";
	String setting_flowc = "";

	String[] Setting_baudrate = {"1200", "9600", "14400"
			, "19200", "28800", "38400", "57600"
			, "76800", "115200", "128000", "153600"
			, "230400", "460800", "500000", "921600"};
	String[] Setting_data = {"7", "8"};
	String[] Setting_parity = {"none", "odd", "even"};//0 , 1 , 2
	String[] Setting_stopbit = {"none", "1 bit"};
	String[] Setting_flowc = {"not support"};

	static Handler handler;

	Handler handler_pd = new Handler() {
		@Override
		public void handleMessage(Message msg) {

			switch (msg.what) {
				case 0: {
					if (pd != null)
						pd.dismiss();
					break;
				}
				default:
					break;
			}
		}

		;
	};

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		StrictMode
				.setThreadPolicy(new StrictMode.ThreadPolicy.Builder()
						.detectDiskReads()
						.detectDiskWrites()
						.detectNetwork()   // or .detectAll() for all detectable problems
						.penaltyLog()
						.build());
		StrictMode
				.setVmPolicy(new StrictMode.VmPolicy.Builder()
						.detectLeakedSqlLiteObjects()
						.detectLeakedClosableObjects()
						.penaltyLog()
						.penaltyDeath()
						.build());

		requestWindowFeature(Window.FEATURE_NO_TITLE);
	}

	@Override
	protected void onStart() {
		super.onStart();

		getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
				WindowManager.LayoutParams.FLAG_FULLSCREEN);
		setContentView(R.layout.activity_main);

		initData();
		initComponent();
		initComponentAction();

		if (rcvThread == null) {
			rcvThreadExit = false;
			rcvThread = new recvThread();
			rcvThread.start();
		}

//		btn_scanDevices.performClick();
	}

	@Override
	public void onWindowFocusChanged(boolean hasFocus) {
		super.onWindowFocusChanged(hasFocus);

	}

	@Override
	protected void onResume() {
		super.onResume();

		if (g_d != null)
			g_d.setCmd("stop");
			rcvThreadExit = false;
			rcvThread = new recvThread();
			rcvThread.start();
	}

	@Override
	protected void onStop() {

		rcvThreadExit = true;
		if (mNSD != null) {
			stopDiscover();
		}
		super.onStop();

	}

	@Override
	protected void onDestroy() {
		rcvThreadExit = true;
		if (mNSD != null) {
			stopDiscover();
		}
		super.onDestroy();
	}

	private void initData() {

		itemDragView = new View[deviceNumberMax];

		if (configuredDevices == null) {
			configuredDevices = new DeviceInfo[deviceNumberMax];
			for (int i = 0; i < deviceNumberMax; i++) {
				configuredDevices[i] = new DeviceInfo();
				configuredDevices[i].setaliveFlag(0);
				configuredDevices[i].setNameGroup("");
				configuredDevices[i].setName("");
				configuredDevices[i].setName_small("");
				configuredDevices[i].setIP("");
				configuredDevices[i].setPort(0);
				configuredDevices[i].setmacAdrress("");
				configuredDevices[i].setimg(R.drawable.device);
			}
		}
		if (settingListdDevices == null) {
			settingListdDevices = new DeviceInfo[deviceNumberMax];
			for (int i = 0; i < deviceNumberMax; i++) {
				settingListdDevices[i] = new DeviceInfo();
				settingListdDevices[i].setaliveFlag(0);
				settingListdDevices[i].setNameGroup("");
				settingListdDevices[i].setName("");
				settingListdDevices[i].setName_small("");
				settingListdDevices[i].setIP("");
				settingListdDevices[i].setPort(0);
				settingListdDevices[i].setmacAdrress("");
				settingListdDevices[i].setimg(R.drawable.device);
			}
		}


		if (infoDevices == null) {
			infoDevices = new DeviceInfo[DEVICE_MAX_NUM];
			for (int i = 0; i < DEVICE_MAX_NUM; i++) {
				infoDevices[i] = new DeviceInfo();
				infoDevices[i].setaliveFlag(0);
				infoDevices[i].setName("");
				infoDevices[i].setName_small("");
				infoDevices[i].setIP("");
				infoDevices[i].setPort(0);
				infoDevices[i].setmacAdrress("");
				infoDevices[i].setimg(R.drawable.device);
			}
		}

		if (arrayGroupID == null) {
			arrayGroupID = new String[groupNumberMax];
			for (int i = 0; i < groupNumberMax; i++) {
				arrayGroupID[i] = "0";
			}
		}

	}


	private void initComponent() {
		btn_scanDevices = null;
		btn_setting = null;
		pd = null;

		btn_scanDevices = (ImageButton) findViewById(R.id.btn_scanDevices);
		btn_setting = (ImageButton) findViewById(R.id.btn_setting);
		gridView = (GridView) findViewById(R.id.gridview_list);

		if (adapter_deviceInfo == null) {
			adapter_deviceInfo = new SimpleAdapter(this, devInfoList,
					R.layout.layout_item, new String[]{"item_image", "item_text"},
					new int[]{R.id.item_image, R.id.item_text});
		}
		if (adapter_deviceInfo_setting == null) {
			adapter_deviceInfo_setting = new SimpleAdapter(this, devInfoList,
					R.layout.layout_item_setting, new String[]{"item_image", "item_text", "item_text_info"},
					new int[]{R.id.item_image, R.id.item_text, R.id.item_text_info});
		}

		gridViewItemComponent();

		for (int i = 0; i < DEVICE_MAX_NUM; i++) {
			if (infoDevices[i].getaliveFlag() > 0) {
				reloadDeviceInfo();
				break;
			}
		}
	}

	private void device_config(int index) {


		String listSelectedName = null;

		g_ctrl.resetInfo();
		Map<String, Object> map = null;
		map = devInfoList.get(index);
		listSelectedName = (String) map.get("item_text");
		listSelectedGroupName = (String) map.get("item_group_info");
		listSelectedGroupID = (String) map.get("item_group_id");
		int deviceInfoIndex = -1;
		deviceNumberNow = g_ctrl.getDeviceList().size();
			for (int i = 0; i < deviceNumberNow; i++) {
				if (infoDevices[i].getName().equalsIgnoreCase(listSelectedName)) {
					deviceInfoIndex = i;
					break;
				}
			}

			if (g_ctrl.getDeviceList().elementAt(deviceInfoIndex) == null)
				return;
			g_ctrl.setConnIP(g_ctrl.getDeviceList().elementAt(deviceInfoIndex).getInetAddress());
			g_ctrl.setConnPort(g_ctrl.getDeviceList().elementAt(deviceInfoIndex).getPort());

			//TODO
			byte[] cmdGet_AllSetting = new byte[]{0x02, 0x00, 0x0f};

			ByteBuffer tmp = ByteBuffer.allocate(cmdPrefix.length + cmdGet_AllSetting.length);
			tmp.clear();
			tmp.put(cmdPrefix);
			tmp.put(cmdGet_AllSetting);
			byte[] test = tmp.array();

			g_ctrl.clearTx();
			g_ctrl.setTx(tmp.array());
			g_ctrl.setCmd("Request");

			ctrlClient = new TcpClient(g_ctrl);
			ctrlClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);


			pd = new ProgressDialog(MainActivity.this);
			pd.setTitle("Serial port");
			pd.setMessage("Please wait...");
			pd.setIndeterminate(true);
			pd.setCancelable(false);
			pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

				@Override
				public void onClick(DialogInterface dialog, int which) {
					dialog.dismiss();
				}
			});
			pd.show();

			//Thread
			Thread gettingThread = new Thread() {
				@Override
				public void run() {

					int retry = 30;
					do {
						try {
							Thread.sleep(500);
						} catch (InterruptedException e) {
							e.printStackTrace();
						}
					} while (retry-- > 0 && recvBuf.length() == 0);

					Message m = new Message();
					m.what = 0;
					handler_pd.sendMessage(m);

					//show serial port setting
					runOnUiThread(new Runnable() {
						@Override
						public void run() {

							Toast.makeText(MainActivity.this,
									recvBuf,
									Toast.LENGTH_SHORT).show();
							String[] type = recvBuf.split(";");
							String[] info = {};

							if (type.length != 4)
							{
								Toast.makeText(MainActivity.this,
										"No response",
										Toast.LENGTH_SHORT).show();
								return;
							}

							for (int i = 0; i < type.length; i++) {
								info = type[i].split(",");

								if (i == 0) {//rate
									setting_rate = info[1];
								} else if (i == 1) {//data
									setting_data = info[1];
								} else if (i == 2) {//parity
									setting_parity = info[1];
								} else if (i == 3) {//stopbit
									setting_stopbit = info[1];
								}/*else if(index==4){//flowcontrol
									setting_flowc = info[1];
								}*/
							}

							recvBuf = "";

							LayoutInflater layoutInflater = (LayoutInflater) getBaseContext()
									.getSystemService(LAYOUT_INFLATER_SERVICE);
							View popupView = layoutInflater.inflate(R.layout.setting_serialport, null);
							final PopupWindow popupWindow = new PopupWindow(
									popupView,
									LayoutParams.WRAP_CONTENT,
									LayoutParams.WRAP_CONTENT);

							Button btnApply = (Button) popupView.findViewById(R.id.btn_setting_apply);
							Button btnCancel = (Button) popupView.findViewById(R.id.btn_setting_cancel);

							//====== baud rate =======
							final Spinner spinner_baudrate = (Spinner) popupView.findViewById(R.id.spinner_baudrate);
							ArrayAdapter<String> adapter_baudrate =
									new ArrayAdapter<String>(MainActivity.this,
											android.R.layout.simple_spinner_item, Setting_baudrate);
							adapter_baudrate.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
							spinner_baudrate.setAdapter(adapter_baudrate);
							int spinnerPosition = adapter_baudrate.getPosition(setting_rate);
							spinner_baudrate.setSelection(spinnerPosition);

							//====== data =======
							final Spinner spinner_data = (Spinner) popupView.findViewById(R.id.spinner_data);
							ArrayAdapter<String> adapter_data =
									new ArrayAdapter<String>(MainActivity.this,
											android.R.layout.simple_spinner_item, Setting_data);
							adapter_data.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
							spinner_data.setAdapter(adapter_data);
							spinnerPosition = adapter_data.getPosition(setting_data);
							spinner_data.setSelection(spinnerPosition);

							//====== parity =======
							final Spinner spinner_parity = (Spinner) popupView.findViewById(R.id.spinner_parity);
							ArrayAdapter<String> adapter_parity =
									new ArrayAdapter<String>(MainActivity.this,
											android.R.layout.simple_spinner_item, Setting_parity);
							adapter_parity.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
							spinner_parity.setAdapter(adapter_parity);
							spinnerPosition = Integer.valueOf(setting_parity).intValue();//adapter_parity.getPosition(parity);
							spinner_parity.setSelection(spinnerPosition);

							//====== stop bit =======
							final Spinner spinner_stopbit = (Spinner) popupView.findViewById(R.id.spinner_stopbit);
							ArrayAdapter<String> adapter_stopbit =
									new ArrayAdapter<String>(MainActivity.this,
											android.R.layout.simple_spinner_item, Setting_stopbit);
							adapter_stopbit.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
							spinner_stopbit.setAdapter(adapter_stopbit);
							spinnerPosition = Integer.valueOf(setting_stopbit).intValue();//adapter_stopbit.getPosition(stopbit);
							spinner_stopbit.setSelection(spinnerPosition);

							//====== flow control=======
							final Spinner spinner_flowc = (Spinner) popupView.findViewById(R.id.spinner_flowcontrol);
							ArrayAdapter<String> adapter_flowc =
									new ArrayAdapter<String>(MainActivity.this,
											android.R.layout.simple_spinner_item, Setting_flowc);
							adapter_flowc.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
							spinner_flowc.setAdapter(adapter_flowc);
							spinnerPosition = adapter_flowc.getPosition(setting_flowc);
							spinner_flowc.setSelection(spinnerPosition);

							btnApply.setOnClickListener(new Button.OnClickListener() {

								@Override
								public void onClick(View v) {
									//TODO
									setting_rate = spinner_baudrate.getSelectedItem().toString();
									setting_data = spinner_data.getSelectedItem().toString();
									setting_parity = spinner_parity.getSelectedItem().toString();
									setting_stopbit = spinner_stopbit.getSelectedItem().toString();
									//setting_flowc 	= spinner_flowc.getSelectedItem().toString();
									g_ctrl.clearTx();
									lastTx = combineReqCmd(setting_rate,
											setting_data,
											setting_parity,
											setting_stopbit/*,
	                                      						setting_flowc*/);
									g_ctrl.setTx(lastTx);

									pd = new ProgressDialog(MainActivity.this);
									pd.setTitle("Serial port");
									pd.setMessage("Please wait...");
									pd.setIndeterminate(true);
									pd.setCancelable(false);
									pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

										@Override
										public void onClick(DialogInterface dialog, int which) {
											dialog.dismiss();
										}
									});
									pd.show();

									//Thread
									Thread settingThread = new Thread() {
										@Override
										public void run() {

											int retry = 20;
											do {
												try {
													Thread.sleep(500);
												} catch (InterruptedException e) {
													e.printStackTrace();
												}
											} while (retry-- > 0 && recvBuf.length() == 0);

											Message m = new Message();
											m.what = 0;
											handler_pd.sendMessage(m);
											g_ctrl.setCmd("stop");
											//show serial port setting
											runOnUiThread(new Runnable() {
												@Override
												public void run() {

													Toast.makeText(MainActivity.this,
															recvBuf,
															Toast.LENGTH_SHORT).show();
													recvBuf = "";
												}

												;
											});
										}
									};

									if (!(listSelectedGroupName == null)){
										int groupingDeviceMatchIndex = -1;

										for (int i = 0; i < deviceNumberNow; i++) {
											if (configuredDevices[i].getName_small().equalsIgnoreCase(listSelectedGroupID)) {
												g_ctrl.setTx(lastTx);
												g_ctrl.setCmd("Request");
												groupingDeviceMatchIndex = i;
												if (g_ctrl.getDeviceList().elementAt(groupingDeviceMatchIndex) == null)
													return;
												g_ctrl.setConnIP(g_ctrl.getDeviceList().elementAt(groupingDeviceMatchIndex).getInetAddress());
												g_ctrl.setConnPort(g_ctrl.getDeviceList().elementAt(groupingDeviceMatchIndex).getPort());
												ctrlClient = new TcpClient(g_ctrl);
												ctrlClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);

												int retry = 20;
												do {
													try {
														Thread.sleep(500);
													} catch (InterruptedException e) {
														e.printStackTrace();
													}
												} while (retry-- > 0 && recvBuf.length() == 0);

												Message m = new Message();
												m.what = 0;
												handler_pd.sendMessage(m);
												g_ctrl.setCmd("stop");
												//show serial port setting
												runOnUiThread(new Runnable() {
													@Override
													public void run() {

														Toast.makeText(MainActivity.this,
																recvBuf,
																Toast.LENGTH_SHORT).show();
														recvBuf = "";
													}

													;
												});
											}
										}

									}else{
										g_ctrl.setCmd("Request");
										ctrlClient = new TcpClient(g_ctrl);
										ctrlClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);
										settingThread.start();
									}

									popupWindow.dismiss();
								}

								private byte[] combineReqCmd(String setting_rate, String setting_data, String setting_parity, String setting_stopbit/*, String setting_flowc*/) {


									//<20150412> So far, flow control no support.
									byte[] cmdSet_rate = null;
									byte[] cmdSet_data = null;
									byte[] cmdSet_parity = null;
									byte[] cmdSet_stopbit = null;
									//byte[] cmdSet_flowc 	= new byte[3];

									if (setting_rate.equals("1200")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0xB0, (byte) 0x04, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("9600")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x80, (byte) 0x25, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("14400")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x40, (byte) 0x38, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("19200")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x4B, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("28800")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x80, (byte) 0x70, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("38400")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x96, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("57600")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0xE1, (byte) 0x00, (byte) 0x00};
									} else if (setting_rate.equals("76800")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x2C, (byte) 0x01, (byte) 0x00};
									} else if (setting_rate.equals("115200")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0xC2, (byte) 0x01, (byte) 0x00};
									} else if (setting_rate.equals("128000")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0xF4, (byte) 0x01, (byte) 0x00};
									} else if (setting_rate.equals("153600")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x58, (byte) 0x02, (byte) 0x00};
									} else if (setting_rate.equals("230400")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x84, (byte) 0x03, (byte) 0x00};
									} else if (setting_rate.equals("460800")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x08, (byte) 0x07, (byte) 0x00};
									} else if (setting_rate.equals("500000")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x20, (byte) 0xA1, (byte) 0x07, (byte) 0x00};
									} else if (setting_rate.equals("921600")) {
										cmdSet_rate = new byte[]{(byte) 0x00, (byte) 0x01, (byte) 0x04, (byte) 0x00, (byte) 0x10, (byte) 0x0E, (byte) 0x00};
									}

									if (setting_data.equals("8")) {
										cmdSet_data = new byte[]{0x00, 0x02, 0x01, 0x08};
									} else {
										cmdSet_data = new byte[]{0x00, 0x02, 0x01, 0x07};
									}

									if (setting_parity.equals("none")) {
										cmdSet_parity = new byte[]{0x00, 0x04, 0x01, 0x00};
									} else if (setting_parity.equals("odd")) {
										cmdSet_parity = new byte[]{0x00, 0x04, 0x01, 0x01};
									} else if (setting_parity.equals("even")) {
										cmdSet_parity = new byte[]{0x00, 0x04, 0x01, 0x02};
									}

									if (setting_stopbit.equals("none")) {
										cmdSet_stopbit = new byte[]{0x00, 0x08, 0x01, 0x00};
									} else if (setting_stopbit.equals("1 bit")) {
										cmdSet_stopbit = new byte[]{0x00, 0x08, 0x01, 0x01};
									}

									byte[] reqCmdByte = new byte[]{0x00};

									//combine req cmd
									ByteBuffer reqTmp = ByteBuffer.allocate(cmdPrefix.length +
											reqCmdByte.length +
											cmdSet_rate.length +
											cmdSet_data.length +
											cmdSet_parity.length +
											cmdSet_stopbit.length);


									reqTmp.clear();
									reqTmp.put(cmdPrefix);
									reqTmp.put(reqCmdByte);
									reqTmp.put(cmdSet_rate);
									reqTmp.put(cmdSet_data);
									reqTmp.put(cmdSet_parity);
									reqTmp.put(cmdSet_stopbit);
									//byte[] test = reqTmp.array();

									return reqTmp.array();
								}

							});

							btnCancel.setOnClickListener(new Button.OnClickListener() {

								@Override
								public void onClick(View v) {
									g_ctrl.setCmd("stop");
									popupWindow.dismiss();
								}
							});
							popupWindow.showAtLocation(popupView, Gravity.CENTER, 0, 0);
						}

					});
				}
			};
			gettingThread.start();

	}

	private void initComponentAction() {
		btn_scanDevices.setOnClickListener(new OnClickListener() {

			@Override
			public void onClick(View arg0) {

				pd = new ProgressDialog(MainActivity.this);
				pd.setTitle("Searching...");
				pd.setMessage("Please wait...");
				pd.setIndeterminate(true);
				pd.setCancelable(false);
				pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

					@Override
					public void onClick(DialogInterface dialog, int which) {

						stopDiscover();
						dialog.dismiss();
					}
				});
				pd.show();

				//Thread
				Thread searchThread = new Thread() {
					@SuppressLint("NewApi")
					@Override
					public void run() {

						long tStart = 0;
						g_d.ResolveStatusReset();
						devInfoList.clear();
						g_ctrl.clearDeviceList();
						infoDevices = null;
						settingListdDevices = null;
						initData();

						int tmp = 0;
						tStart = System.currentTimeMillis();
						try {
							do {
								startDiscover();

								Thread.sleep(40000);

								tmp++;
							} while (tmp < 1);
							g_ctrl.ResolveStatusReset();
						} catch (InterruptedException e) {
							e.printStackTrace();
						}

						Message m = new Message();
						m.what = 0;
						handler_pd.sendMessage(m);


						if (tmp >= 3 && (g_ctrl.getDeviceList().size() == 0)) {
							runOnUiThread(new Runnable() {
								@Override
								public void run() {

									Toast.makeText(MainActivity.this,
											"Devices search timeout!",
											Toast.LENGTH_SHORT).show();
								}

							});
						}

						deviceNumberNow = g_ctrl.getDeviceList().size();

						String groupID;
						if (deviceNumberNow == 0) {
							devInfoList.clear();
							g_ctrl.clearDeviceList();
							infoDevices = null;
							initData();
						} else {
							for (int i = 0; i < deviceNumberNow; i++) {

								groupID = g_ctrl.getDeviceList().elementAt(i).getNiceTextString().substring(g_ctrl.getDeviceList().elementAt(i).getNiceTextString().indexOf("groupid:") + 8, g_ctrl.getDeviceList().elementAt(i).getNiceTextString().indexOf("groupid:") + 9).toString();

								infoDevices[i].setaliveFlag(1);
								infoDevices[i].setName(g_ctrl.getDeviceList().elementAt(i).getName());
								infoDevices[i].setName_small(groupID);

								infoDevices[i].setIP(g_ctrl.getDeviceList().elementAt(i).getHostAddress());
								infoDevices[i].setPort(g_ctrl.getDeviceList().elementAt(i).getPort());
								infoDevices[i].setmacAdrress("");

								configuredDevices[i].setaliveFlag(infoDevices[i].getaliveFlag());
								configuredDevices[i].setNameGroup(infoDevices[i].getNameGroup());
								configuredDevices[i].setName(infoDevices[i].getName());
								configuredDevices[i].setName_small(infoDevices[i].getName_small());
								configuredDevices[i].setIP(infoDevices[i].getIP());
								configuredDevices[i].setPort(infoDevices[i].getPort());
								configuredDevices[i].setmacAdrress(infoDevices[i].getmacAdrress());
								configuredDevices[i].setimg(infoDevices[i].getimg());

								if (!groupID.equals("0")) {
									for (int j = 0; j < groupNumberMax; j++) {
										if (arrayGroupID[j].equals("0")) {
											arrayGroupID[j] = groupID;
										} else {
											if (arrayGroupID[j].equals(groupID))
												break;
											else
												continue;
										}
									}
								}

							}

							int j = 0;
							while (j < groupNumberMax && !arrayGroupID[j].equals("0") ) {

										String groupName = "";
								for (int i = 0; i < deviceNumberNow; i++) {
									if (infoDevices[i].getName_small().equals(arrayGroupID[j])) {
										infoDevices[i].setimg(R.drawable.ameba_group);
										if (groupName.equals(""))
											groupName = infoDevices[i].getName();
										infoDevices[i].setNameGroup(groupName);
									}
								}
								j++;
							}

						}
						runOnUiThread(new Runnable() {
							@Override
							public void run() {

								//show scan result

								reloadDeviceInfo();
								Toast.makeText(MainActivity.this,
										String.valueOf(devInfoList.size()) + " Ameba Found",
										Toast.LENGTH_SHORT).show();


							}

						});
					}
				};
				searchThread.start();
			}
		});

		btn_setting.setOnClickListener(new OnClickListener() {

			@Override
			public void onClick(View arg0) {

				if (adapter_deviceInfo_setting.getCount() == 1) //only one device don't need setting_builder
					device_config(0);
				else {
					AlertDialog.Builder setting_builder;
					setting_builder = new AlertDialog.Builder(MainActivity.this);

					setting_builder.setTitle("Choose One Ameba");
					setting_builder.setCancelable(false);
					setting_builder.setSingleChoiceItems(adapter_deviceInfo_setting, -1, new DialogInterface.OnClickListener() {

						@SuppressLint("NewApi")
						@Override
						public void onClick(DialogInterface dialog, final int index) {
							device_config(index);
							dialog.cancel();

						}

					});
					setting_builder.setPositiveButton("Cancel", new DialogInterface.OnClickListener() {
						public void onClick(DialogInterface dialog, int whichButton) {

						}
					});

					setting_builder.create().show();
				}
			}
		});


		//======================= action ======================
		//search devices when no device
		boolean isSearchTrigger = true;
		for (int i = 0; i < DEVICE_MAX_NUM; i++) {
			if (infoDevices[i].getaliveFlag() > 0) {
				isSearchTrigger = false;
				break;
			}
		}

//			btn_scanDevices.performClick();


	}

	protected int parseInfo(String recvBuf) {
		//TODO	

		return 1;

		//-------- response for getting --------

	}


	private void gridViewItemComponent() {


			gridView.setOnTouchListener(new OnTouchListener() {
				private final int MAX_CLICK_DURATION = 400;
				private final int MAX_CLICK_DISTANCE = 100;
				private long startClickTime;
				private float x1;
				private float y1;
				private float x2;
				private float y2;
				private float dx;
				private float dy;


				@SuppressLint("InlinedApi")
				@Override
				public boolean onTouch (View v, MotionEvent me){

					handler=new Handler();



					Map<String, Object> map = null;

					float currentXPosition = me.getX();
					float currentYPosition = me.getY();
					int position = gridView.pointToPosition((int) currentXPosition,
							(int) currentYPosition);
					int event_index = me.getAction();

					View test = gridView.getChildAt(position);
					if(location != null && test!= null) {
						test.getLocationOnScreen(location);
					}
					switch (event_index) {
						case MotionEvent.ACTION_DOWN: {
							actionUP = false;
							popMenushow = false;
							if (configuredDevices == null)
								return false;
							mLastMotionX = (int)currentXPosition;
							mLastMotionY = (int)currentYPosition;
							startClickTime = Calendar.getInstance().getTimeInMillis();
							x1 = me.getX();
							y1 = me.getY();

							isMoved = false;
							handler.postDelayed(mLongPressRunnable, (long) (ViewConfiguration.getLongPressTimeout() ));
							moveCount = 0;

							for (int i = 0; i < adapter_deviceInfo.getCount(); i++) {
								if (i < deviceNumberMax) {
									itemDragView[i] = null;
								}
							}

							if (position < 0) {
								selectedItemName = "";
								return false;
							}
							try {
								map = devInfoList.get(position);
							}catch (IndexOutOfBoundsException e){
								break;
							}
								selectedItemName = (String) map.get("item_text");

							for (int i = 0; i < deviceNumberMax; i++) {
								if (selectedItemName.equals(configuredDevices[i].getNameGroup())) {
									SelectedDeviceInfo = configuredDevices[i];
									break;
								}
							}

							break;
						}
						case MotionEvent.ACTION_MOVE: {
							actionUP = false;
							if(Math.abs(mLastMotionX-(int)currentXPosition) == 0
									&& Math.abs(mLastMotionY -(int)currentYPosition) == 0) {

								return false;
							}

							isMoved = true;
							actionUP = true;
							if (position < 0 || popMenushow == true)
								return false;

							isWaitUpdate = true;

							for (int i = 0; i < deviceNumberMax; i++) {
								if (selectedItemName.equals(configuredDevices[i].getName())) {
									if (configuredDevices[i].getimg() == R.drawable.ameba_group)
										return false;
								}
							}

							View view = gridView.getChildAt(position - gridView.getFirstVisiblePosition());

							map = devInfoList.get(position);
							selectedItemName = (String) map.get("item_text");
							dropItemName = selectedItemName;

							draggedIndex = position;
							view.setTag(IMAGEVIEW_TAG);

							ClipData.Item item = new ClipData.Item((CharSequence) view.getTag());

							String[] mimeTypes = {ClipDescription.MIMETYPE_TEXT_PLAIN};
							ClipData data = new ClipData(view.getTag().toString(),
									mimeTypes, item);
							DragShadowBuilder shadowBuilder = new View.DragShadowBuilder(
									view);

							view.startDrag(data, // data to be dragged
									shadowBuilder, // drag shadow
									view, // local data about the drag and drop
									// operation
									0 // no needed flags
							);

						if (adapter_deviceInfo.getCount() < 2)
							return false;

						view.getBackground().setAlpha(45);
						view.setAlpha(0.50f);

						for (int i = 0; i < adapter_deviceInfo.getCount(); i++) {
							if (i < deviceNumberMax) {

								itemDragView[i] = gridView.getChildAt(i - gridView.getFirstVisiblePosition());
								if (itemDragView[i] != null) {
									itemDragView[i].setOnDragListener(new DeviceDragListener());
								} else {
									//Log.e(TAG,"set DeviceDragListener error:"+String.valueOf(i));
								}
							}
						}


							break;

						}
						case MotionEvent.ACTION_UP: {

							actionUP = true;


							if(popupMenu != null && popMenushow == false) {
                                popupMenu.dismiss();
                            }
                           // popMenushow = false;
							if (configuredDevices == null)
								return false;

							moveCount = 0;
							long clickDuration = Calendar.getInstance().getTimeInMillis() - startClickTime;
							x2 = me.getX();
							y2 = me.getY();
							dx = x2 - x1;
							dy = y2 - y1;

							if (clickDuration < MAX_CLICK_DURATION
									&& dx < MAX_CLICK_DISTANCE
									&& dy < MAX_CLICK_DISTANCE) {

								if (position < 0) {
									return false;
								}

								map = devInfoList.get(position);
								selectedItemName = (String) map.get("item_text");

								for (int i = 0; i < deviceNumberMax; i++) {
									if (selectedItemName.equals(configuredDevices[i].getName())) {

										if (configuredDevices[i].getimg() == R.drawable.ameba_group) {

											task_updateMDNS_enable = false;


											for (int j = 0; j < deviceNumberMax; j++) {
												if (selectedItemName.equals(configuredDevices[j].getaliveFlag())) {
													SelectedDeviceInfo = configuredDevices[j];
													break;
												}
											}

											break;
										} else {
											//disable led

											for (int j = 0; j < deviceNumberMax; j++) {
												if (selectedItemName.equals(configuredDevices[j].getName())) {

													break;
												}
											}

										}

									} else {
										//Log.d(TAG,"DEBUG "+configuredDevices[i].getName());
									}
								}

							} else {

								for (int i = 0; i < deviceNumberMax; i++) {
									if (configuredDevices[i].getaliveFlag() > 0) {
										if (selectedItemName.equals(configuredDevices[i].getName())) {
											break;
										}

									}
								}
							}
							selectedItemName = "";
							break;
						}
						default: {

							if (event_index == 1)//cancel
								moveCount = 0;
							break;
						}
					}

					return false;
				}



			});

		gridView.setLongClickable(true);
		gridView.setOnItemLongClickListener(new OnItemLongClickListener() {

			@Override
			public boolean onItemLongClick(AdapterView<?> parent, View view,
										   int position, long id) {

				int popMenuHeight = -2;

				mPosition = position;

				Map<String, Object> map = null;
				map = devInfoList.get(position);
				listSelectedGroupName = (String) map.get("item_group_info");
				listSelectedGroupID = (String) map.get("item_group_id");




				LayoutInflater layoutInflater = (LayoutInflater) getBaseContext()
						.getSystemService(LAYOUT_INFLATER_SERVICE);
				View popupView = layoutInflater.inflate(R.layout.layout_popmenu , null);



				Button btnUngroup = (Button) popupView.findViewById(R.id.unGrouptBtn);
				btnSetting = (Button) popupView.findViewById(R.id.btn_setting);
				btnSetting.post(new Runnable() {
					@Override
					public void run() {
						btn_height = btnSetting.getHeight(); //height is ready
					}
				});

				if (listSelectedGroupName == null)
					popMenuHeight = ((int)(btnSetting.getLineHeight()/10)) *20;
				else
					popMenuHeight = (((int)(btnSetting.getLineHeight()/10)) *20) * 2;


				popupMenu = new
						PopupWindow(
						popupView,
						LayoutParams.WRAP_CONTENT,
						popMenuHeight);

				popupMenu.showAtLocation(view, Gravity.LEFT | Gravity.TOP, location[0], location[1]);
				popMenushow = true;

				btnSetting.setOnClickListener(new OnClickListener() {

					@Override
					public void onClick(View arg0) {
						device_config(mPosition);
						popupMenu.dismiss();
					}
				});

				btnUngroup.setOnClickListener(new OnClickListener() {

					@Override
					public void onClick(View arg0) {

						popupMenu.dismiss();
						g_ctrl.setCmd("Request");

						for (int i = 0; i < deviceNumberNow; i++) {

							if (configuredDevices[i].getName_small().equalsIgnoreCase(listSelectedGroupID)) {
								device_pairing(-1, i, -1, 2);    //ungroup
								configuredDevices[i].setNameGroup("");
								configuredDevices[i].setName_small("");
							}
						}
						btn_scanDevices.callOnClick();
					}
				});

				return true;
			}
		});

		gridView.setOnItemClickListener(new OnItemClickListener() {

				@SuppressLint("NewApi")
				@Override
				public void onItemClick(AdapterView<?> arg0, View v, int position, long id) {

					Thread pdRunThread = new Thread() {
						@Override
						public void run() {
							Looper.prepare();
							pd = new ProgressDialog(MainActivity.this);
							pd.setTitle("Connecting");
							pd.setMessage("Please wait...");
							pd.setIndeterminate(true);
							pd.setCancelable(false);
							pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

								@Override
								public void onClick(DialogInterface dialog, int which) {
									dialog.dismiss();
								}
							});
							pd.show();
							Looper.loop();
						}
					};
					pdRunThread.start();



					Map<String, Object> map = null;
					map = devInfoList.get(position);
					listSelectedGroupName = (String) map.get("item_group_info");

					if (listSelectedGroupName != null) {
						listSelectedGroupName = null;
						return;
					}

					//TODO
					Toast.makeText(MainActivity.this, "Connect to " + infoDevices[position].getName(), Toast.LENGTH_SHORT).show();

					for (int i = 0; i < g_d.getDeviceList().size(); i++) {
						if (g_ctrl.getDeviceList().elementAt(position).getInetAddress().equals(g_d.getDeviceList().elementAt(i).getInet4Address())) {
							position = i;
							break;
						}
					}

					g_d.resetInfo();
					g_d.setConnIP(g_d.getDeviceList().elementAt(position).getInetAddress()); //need check
					g_d.setConnPort(g_d.getDeviceList().elementAt(position).getPort());
					g_d.setCmd("Hello");



/*
												cont_pd = new ProgressDialog(MainActivity.this);
												cont_pd.setTitle("Connecting...");
												cont_pd.setMessage("Please wait...");
												cont_pd.setIndeterminate(true);
												cont_pd.setCancelable(false);
												cont_pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {
													@Override
													public void onClick(DialogInterface dialog, int which) {
														dialog.dismiss();
													}
												});
												cont_pd.show();

*/
					dataClient = new TcpClient(g_d,MainActivity.this);
					Thread runThread = new Thread() {
						@Override
						public void run() {
							dataClient.onPreExecute();
							moveCount = 1;
						}
					};
					runThread.start();

					do {
						try {
							Thread.sleep(500);
						}catch (InterruptedException e){}
					} while (moveCount == 0);
					dataClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);

					g_d.opStates().setOpState(g_d.opStates().stateConnectedServer());

					Message m = new Message();
					m.what = 0;
					handler_pd.sendMessage(m);

					Intent intent_Navigation = new Intent();
					intent_Navigation.setClass(MainActivity.this, ChatActivity.class);
					startActivity(intent_Navigation);
					finish();
				}
			}

			);
		}

	private void startDiscover() {
		g_discoverEnable = true;

		if (mNSD != null) {
			stopDiscover();
		}
		mNSD = new NsdCore(this);
		mNSD.initializeNsd();

		mNSD.discoverServices(g_d.getServiceType());
		mNSD.discoverServices(g_ctrl.getServiceType());

		if (uiThread == null) {
			uiThread = new UpdateUiThread();
			uiThread.start();
		}

		g_d.opStates().setOpState(g_d.opStates().stateDiscoveringService());
		g_ctrl.opStates().setOpState(g_d.opStates().stateDiscoveringService());
	}

	private void stopDiscover() {

		g_discoverEnable = false;

		if (mNSD != null)
			mNSD.stopDiscovery();

		g_d.opStates().setOpState(g_d.opStates().stateAppStart());
		g_ctrl.opStates().setOpState(g_d.opStates().stateAppStart());
	}

	private void reloadDeviceInfo() {
		boolean dup = false;
		devInfoList.clear();
		if (infoDevices.length > 0) {
			for (int i = 0; i < infoDevices.length; i++) {

				if (infoDevices[i].getaliveFlag() == 1) {
					for (int j = 0; j < devInfoList.size(); j++) {
						if( devInfoList.get(j) != null ){
							if( !infoDevices[i].getName_small().equals("0") &&  infoDevices[i].getName_small().equals(devInfoList.get(j).get("item_group_id")) ) {
								dup = true;//grouped and
							}
						}else {
							break;
						}


					}
					if(!dup) {
						HashMap<String, Object> reloadItemHashMap = new HashMap<String, Object>();
						reloadItemHashMap.put("item_image", infoDevices[i].getimg());
						reloadItemHashMap.put("item_text", infoDevices[i].getName());
						reloadItemHashMap.put("item_text_info", infoDevices[i].getIP());
						reloadItemHashMap.put("item_group_info", infoDevices[i].getNameGroup());
						reloadItemHashMap.put("item_group_id", infoDevices[i].getName_small());
						devInfoList.add(reloadItemHashMap);
					}
					dup = false;
				}

			}
			gridView.setAdapter(adapter_deviceInfo);
		}

	}

	public class recvThread extends Thread {


		//======================= Thread ======================


		@Override
		public void run() {

			while (!rcvThreadExit) {

				if (g_ctrl.checkRecvBufUpdate() && g_ctrl.pullRecvBuffer().length() > 0) {

					_gmutex_recvBuf.lock();

					if(g_ctrl.pullRecvBuffer().length() != 0 )
						recvBuf = g_ctrl.pullRecvBuffer();
					g_ctrl.resetRecvBuffer();

					_gmutex_recvBuf.unlock();

					if (parseInfo(recvBuf) < 0)
						Log.e(TAG, "parseInfo(recvBuf) Fail!!!!!");
				}

				try {
					Thread.sleep(100);
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			}
		}

	}

	/*
     * Class - UpdateUiThread
     */
	public class UpdateUiThread extends Thread {

		Globals_d g_d = Globals_d.getInstance();

		private static final int DELAY = 200; // ms

		@Override
		public void run() {

			while (g_discoverEnable) {

				try {
					Thread.sleep(DELAY);
				} catch (InterruptedException e) {

					return;
				}
			}
		}

	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}


	@SuppressLint("NewApi")
	class DeviceDragListener implements OnDragListener {
		//Drawable normalShape = getResources().getDrawable(R.drawable.normal_shape);
		//Drawable selectShape = getResources().getDrawable(R.drawable.select_shape);
		//Drawable targetShape = getResources().getDrawable(R.drawable.target_shape);

		String cmd = "";

		@Override
		public boolean onDrag(final View v, DragEvent event) {
			int indexSelected = -1;
			Map<String, Object> map;

			switch (event.getAction()) {

				case DragEvent.ACTION_DRAG_STARTED:
					break;
				case DragEvent.ACTION_DRAG_ENTERED:
					break;
				case DragEvent.ACTION_DRAG_EXITED:
					break;
				case DragEvent.ACTION_DROP:

					String addGroupName = "";
					String originGroupName = "";
					indexSelected = -1;
					int attachedNum = 0;

					if (adapter_deviceInfo.getCount() < 2)
						return true;
					else {
						//Log.d(TAG,"before device number:"+String.valueOf(adapter_deviceInfo.getCount()));
					}

					boolean ret_indexSelected = false;
					for (int i = 0; i < adapter_deviceInfo.getCount(); i++) {
						if (i < deviceNumberMax) {
							itemDragView[i] = gridView.getChildAt(i - gridView.getFirstVisiblePosition());
							if (itemDragView[i] != null) {
								itemDragView[i].setOnDragListener(new DeviceDragListener());
							} else {
								//Log.e(TAG,"set DeviceDragListener error:"+String.valueOf(i));
							}
						}
					}

					for (int iSP = 0; iSP < MainActivity.deviceNumberMax; iSP++) {
						if ((v == itemDragView[iSP]) && (draggedIndex != iSP)) {
							indexSelected = iSP;
							ret_indexSelected = true;
							break;
						}
					}
					if (ret_indexSelected == false) {

						return true;
					}

					map = devInfoList.get(indexSelected);
					originGroupName = (String) map.get("item_text");
					map = devInfoList.get(draggedIndex);
					addGroupName = (String) map.get("item_text");
					dropItemName = (String) map.get("item_text");

					for (int i = 0; i < deviceNumberMax; i++) {
						if (dropItemName.equals(configuredDevices[i].getNameGroup())) {
							SelectedDeviceInfo = configuredDevices[i];
							break;
						}
					}

					mindexSelected = indexSelected;
					mDraggedIndex = draggedIndex;

					pd = new ProgressDialog(MainActivity.this);
					pd.setTitle("Pairing...");
					pd.setMessage("Please wait...");
					pd.setIndeterminate(true);
					pd.setCancelable(false);
					pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

						@Override
						public void onClick(DialogInterface dialog, int which) {
							g_ctrl.clearTx();
							dialog.dismiss();
						}
					});
					pd.show();

					Thread settingThread = new Thread() {
						@Override
						public void run() {
							g_ctrl.setCmd("Request");
							device_pairing(mDraggedIndex, mindexSelected, -1, 0);
							device_pairing(mindexSelected, mDraggedIndex, -1, 0);
							device_pairing(mindexSelected, mDraggedIndex, mGroupID, 1);
							device_pairing(mDraggedIndex, mindexSelected ,mGroupID, 1);

							g_ctrl.clearCmd();


							int retry = 20;
							do {
								try {
									Thread.sleep(500);
								} catch (InterruptedException e) {
									e.printStackTrace();
								}
							} while (retry-- > 0 && recvBuf.length() == 0);

							recvBuf = "";
							pd.dismiss();
							runOnUiThread(new Runnable() {
								@Override
								public void run() {

									Toast.makeText(MainActivity.this,
											"OK",
											Toast.LENGTH_SHORT).show();


								}

								;
							});

						}
					};

					settingThread.start();

					//check limit about the number of one group could not be over 8
					int numberLimit = 0;
					for (int i = 0; i < deviceNumberMax; i++) {
						if (originGroupName.equals(configuredDevices[i].getNameGroup())) {
							numberLimit++;
						} else if (addGroupName.equals(configuredDevices[i].getNameGroup())) {
							numberLimit++;
						}

						if (numberLimit > 8) {

							AlertDialog.Builder infoAlert = new AlertDialog.Builder(MainActivity.this);

							infoAlert.setTitle("Warning");
							infoAlert.setMessage("The maximum eight devices can be accessed in one group!");
							infoAlert.setPositiveButton("OK", null);
							infoAlert.show();

							return true;
						}
					}


					//======== send rtmr command ========
					//====check SelectedDeviceInfo ====
					for (int i = 0; i < deviceNumberMax; i++) {
						if (originGroupName.equals(configuredDevices[i].getName())) {
							configuredDevices[i].setimg(R.drawable.ameba_group);
							configuredDevices[i].setNameGroup(originGroupName);
							SelectedDeviceInfo = configuredDevices[i];
							break;
						}
					}

					//====check attachedDeviceInfo ====   (add group -> origin group)
					//check attachedDeviceInfo origin group info
					for (int i = 0; i < deviceNumberMax; i++) {
						if (originGroupName.equals(configuredDevices[i].getNameGroup())) {
							if (!originGroupName.equals(configuredDevices[i].getName())) {
								attachedDeviceInfo[attachedNum] = configuredDevices[i];
								attachedNum++;
							}
						}
					}
					//check attachedDeviceInfo add group info with slave
					for (int i = 0; i < deviceNumberMax; i++) {
						if (addGroupName.equals(configuredDevices[i].getNameGroup())) {
							//check slave
							if (!addGroupName.equals(configuredDevices[i].getName())) {
								attachedDeviceInfo[attachedNum] = configuredDevices[i];
								configuredDevices[i].setNameGroup(originGroupName);
								configuredDevices[i].setaliveFlag(2); //slave
								attachedNum++;
							}
						}

					}

					//check attachedDeviceInfo add group info with master
					for (int i = 0; i < deviceNumberMax; i++) {
						if (addGroupName.equals(configuredDevices[i].getNameGroup())) {
							//check master
							if (addGroupName.equals(configuredDevices[i].getName())) {
								attachedDeviceInfo[attachedNum] = configuredDevices[i];
								configuredDevices[i].setNameGroup(originGroupName);
								configuredDevices[i].setaliveFlag(2); //slave
								attachedNum++;
							}
						}

					}
					configuredDevices[indexSelected].setNameGroup(originGroupName);
					configuredDevices[draggedIndex].setNameGroup(originGroupName);


					HashMap<String, Object> itemHashMap = new HashMap<String, Object>();

					for (int id = 1; id < groupNumberMax; id++) {
						for (int j = 0; j < groupNumberMax; j++) {

							if (!arrayGroupID[j].equals("0") && id < Integer.valueOf(arrayGroupID[j])) {
								mGroupID = id;
								configuredDevices[indexSelected].setName_small(String.valueOf(id));
								configuredDevices[draggedIndex].setName_small(String.valueOf(id));
								itemHashMap.put("item_group_id", String.valueOf(id));
								if (j + 1 != groupNumberMax)
									arrayGroupID[j + 1] = String.valueOf(id);
								id = groupNumberMax;
								break;
							} else if (arrayGroupID[j].equals("0")) {
								mGroupID = id;
								configuredDevices[indexSelected].setName_small(String.valueOf(id));
								configuredDevices[draggedIndex].setName_small(String.valueOf(id));
								itemHashMap.put("item_group_id", String.valueOf(id));
								id = groupNumberMax;
								break;
							} else if (!arrayGroupID[j].equals("0") && !(id < Integer.valueOf(arrayGroupID[j]))) {

								break;
							}

						}
					}

					isTIPEnd = true;
					isWaitUpdate = true;

					// update item

					itemHashMap.put("item_image", R.drawable.ameba_group);
					itemHashMap.put("item_text", originGroupName);
					itemHashMap.put("item_group_info", originGroupName);
					devInfoList.set(indexSelected, itemHashMap);

					gridView.setAdapter(adapter_deviceInfo);

					// remove item
					devInfoList.remove(draggedIndex);
					gridView.setAdapter(adapter_deviceInfo);

					break;

				// the drag and drop operation has concluded.
				case DragEvent.ACTION_DRAG_ENDED:

					//v.setBackground(normalShape); // go back to normal shape
					isWaitUpdateCacheCount = 12;


					if (draggedIndex >= 0 && draggedIndex < devInfoList.size()) {
						map = devInfoList.get(draggedIndex);
						selectedItemName = (String) map.get("item_text");
					} else {
						selectedItemName = "";
					}

					selectedItemName = "";
					draggedIndex = -1;
					isTIPEnd = true;
					gridView.setAdapter(adapter_deviceInfo);

					break;

				default:
					break;
			}
			return true;
		}
	}

	private void device_pairing(int connTarget, int ctrlTarget, int nameGroupID, int type) {

		try {
			while (!g_ctrl.getCmd().equalsIgnoreCase("Request")) {

				Thread.sleep(100);
			}

		} catch (InterruptedException e) {
			e.printStackTrace();
		}

		g_ctrl.clearCmd();

		byte[] cmd_ServerCreate;
		byte[] cmdArray;
		ByteBuffer tmp = null;
		byte[] inetToByte = {0};

		g_ctrl.clearTx();
		g_ctrl.resetInfo();

		g_ctrl.setConnIP(g_ctrl.getDeviceList().elementAt(ctrlTarget).getInetAddress());
		g_ctrl.setConnPort(g_ctrl.getDeviceList().elementAt(ctrlTarget).getPort());
		dstCtrlClient = new TcpClient(g_ctrl);


		switch (type) {
			case 0: { // server create
				cmd_ServerCreate = new byte[]{0x00, 0x00, 0x10, 0x02, 0x1f, 0x41};
				tmp = ByteBuffer.allocate(cmdPrefix.length + cmd_ServerCreate.length);
				tmp.clear();
				tmp.put(cmdPrefix);
				tmp.put(cmd_ServerCreate);
				break;
			}
			case 1: { // connect to remote server

				byte[] cmd_ServerConnect = new byte[]{ 0x00, 0x40, 0x06};
				byte[] portToByte = new byte[]{0x1f, 0x41};
				byte[] cmd_group = {0x00, 0x01, 0x00, 0x01,Byte.valueOf(String.valueOf(nameGroupID)) };
				String srcIP[] = g_ctrl.getDeviceList().elementAt(connTarget).getHostAddresses();
				InetAddress ip;

				try {
					ip = InetAddress.getByName(srcIP[0]);
					inetToByte = ip.getAddress();
				} catch (UnknownHostException e1) {
					// TODO Auto-generated catch block
					e1.printStackTrace();
				}

				tmp = ByteBuffer.allocate(cmdPrefix.length + cmd_ServerConnect.length + inetToByte.length + portToByte.length + cmd_group.length);
				tmp.clear();
				tmp.put(cmdPrefix);
				tmp.put(cmd_group);
				tmp.put(cmd_ServerConnect);
				tmp.put(inetToByte);
				tmp.put(portToByte);

				break;
			}
			case 2: { // server delete /ungroup

				cmd_ServerCreate = new byte[]{0x00, 0x00, 0x20, 0x02, 0x1f, 0x41, 0x01, 0x00, 0x01,0x00};
				tmp = ByteBuffer.allocate(cmdPrefix.length + cmd_ServerCreate.length);
				tmp.clear();
				tmp.put(cmdPrefix);
				tmp.put(cmd_ServerCreate);

				break;
			}
			case 3: {//set group id
				byte[] cmd_group = {0x00, 0x01, 0x00, 0x01,Byte.valueOf(String.valueOf(nameGroupID)) };
				tmp = ByteBuffer.allocate(cmdPrefix.length + cmd_group.length);
				tmp.clear();
				tmp.put(cmdPrefix);
				tmp.put(cmd_group);
				break;
			}
			default:
				break;
		}


		cmdArray = tmp.array();

		g_ctrl.setTx(cmdArray);

		dstCtrlClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);


		//Thread
		Thread settingThread = new Thread() {
			@Override
			public void run() {

				int retry = 20;
				do {
					try {
						Thread.sleep(500);
					} catch (InterruptedException e) {
						e.printStackTrace();
					}
				} while (retry-- > 0 && recvBuf.length() == 0);

				g_ctrl.setCmd("stop");
				//show serial port setting
				runOnUiThread(new Runnable() {
					@Override
					public void run() {
						recvBuf = "";
					}

					;
				});
			}
		};
		settingThread.start();
	}

}
