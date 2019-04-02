package com.realtek.uartthrough;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.net.wifi.WifiManager;
import android.content.Context;
import android.provider.Settings;
import android.text.format.Formatter;
import android.util.Log;

import java.lang.String;
import android.net.wifi.WifiInfo;



public class NsdCore {

    private NsdHelper jnsdHelper=null;
    private android.net.wifi.WifiManager.MulticastLock mMulticastLock;
    private android.net.wifi.WifiManager wifi;

	Globals_ctrl g_ctrl = Globals_ctrl.getInstance();
    Globals_d g_d = Globals_d.getInstance();

    Context mContext;



    public static final String TAG 	= "NsdCore";
    static WifiInfo wifiinfo=null;
    public final String mServiceType_c 	= g_ctrl.getServiceType();
    public final String mServiceType_d 	= g_d.getServiceType();

    public String mServiceName_c 	= g_ctrl.getServiceName();
    public String mServiceName_d 	= g_d.getServiceName();
    String mIP ;
    

    public NsdCore(Context context) {
        mContext = context;        
    }

    public void initializeNsd() {

        wifi =  (android.net.wifi.WifiManager)
                        mContext.getSystemService(android.content.Context.WIFI_SERVICE);
        mIP = Formatter.formatIpAddress(wifi.getConnectionInfo().getIpAddress());
        int intaddr = wifi.getConnectionInfo().getIpAddress();
        if (wifi.getWifiState() == WifiManager.WIFI_STATE_DISABLED || intaddr == 0) {
            mContext.startActivity(new Intent(Settings.ACTION_WIFI_SETTINGS));
        } else {
            stopDiscovery();
        }

        

    }

    @SuppressLint("NewApi")
    public void onDestroy() {
        if (mMulticastLock != null) mMulticastLock.release();
    }


    @SuppressLint("NewApi")
	public void discoverServices(String serviceType) {       
    	wifiLock();
        if ( serviceType.contains(mServiceType_c) ) {
        	jnsdHelper = new NsdHelper(serviceType, g_ctrl, mIP);
        	jnsdHelper.executeOnExecutor(NsdHelper.THREAD_POOL_EXECUTOR);
        }else if( serviceType.contains(mServiceType_d) ){
        	NsdHelper jnsdHelper = new NsdHelper(serviceType, g_d, mIP);
        	jnsdHelper.executeOnExecutor(NsdHelper.THREAD_POOL_EXECUTOR);        	
        }

    }

    private void wifiLock() {
        mMulticastLock = wifi.createMulticastLock(getClass().getName());
        mMulticastLock.setReferenceCounted(false);
        mMulticastLock.acquire();
    }

    @SuppressLint("NewApi")
	public void stopDiscovery() {
    	 if (jnsdHelper != null) {

	    	jnsdHelper.onCancelled();
    	 }
    	 if (mMulticastLock != null) 
    		 mMulticastLock.release();
    }
}

