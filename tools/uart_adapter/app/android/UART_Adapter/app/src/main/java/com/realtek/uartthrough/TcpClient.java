package com.realtek.uartthrough;

import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.net.InetAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

///////////////////////////////////////////////
public class TcpClient extends AsyncTask<Void, Void, Void> {

	public static final String TAG 		= "TCP_Client";
    public static final String TAG_CTRL = "TCP_Client(CTRL): ";
    public static final String TAG_DATA = "TCP_Client(DATA): ";
    int type;
    private final Lock _mutex = new ReentrantLock(true);
    private Globals_ctrl g_ctrl ;
    private Globals_d g_d;
    private InetAddress ip;
    int port ;
    String cmd_ctrl_req = "null";
    String cmd_ctrl_response = "null";
    String cmd = "null";
    private Socket s;
    private PrintStream tx;
    private ProgressDialog pd;

    ByteBuffer bf = ByteBuffer.allocate(1024);
    CharBuffer cbuf = bf.asCharBuffer();


    public TcpClient(Globals_ctrl gInstance) {
        g_ctrl = gInstance;
        ip = g_ctrl.getConnIP();
        port = g_ctrl.getConnPort();
        type = 0;

    }

    public TcpClient(Globals_d gInstance, MainActivity activity) {
        g_d = gInstance;
        ip = g_d.getConnIP();
        port = g_d.getConnPort();
        type = 1;
    }

    @Override
    protected void onPreExecute() {
        if(s != null)
            return;
        try {
            s = new Socket(ip, port);
            s.setTcpNoDelay(true);
        }catch (IOException e){}

        do {
            try {
                Thread.sleep(500);
            }catch (InterruptedException e){}
        } while (!s.isConnected());

    }



    @Override
    protected Void doInBackground(Void...params) {

        try {
            //do
            {
            Thread.sleep(1000);


            BufferedInputStream rx = new BufferedInputStream(s.getInputStream());
            tx = new PrintStream(s.getOutputStream());


            switch (type) {
                case 0: // control port
                	
                	g_ctrl.resetInfo();
                	
                	/*==========================
                                        * thread for control TX
                                        * =========================
                                        */
                	new Thread(new Runnable() {
                        public void run() {
                                cmd_ctrl_req = g_ctrl.getCmd();
                                
                                try {
                                        tx.write(g_ctrl.getTx());
                                        g_ctrl.clearTx();
                                } catch (IOException e) {
                                        Log.v(TAG_CTRL,"TX write error");
                        		}
                                g_ctrl.setCmd("Request");
                                
                        }
                    }).start();

                	/*==========================
                                         * for control RX
                                         * =========================
                                         */
                	int len;
                	byte [] recv_buf = new byte[64];
                 	len = rx.read(recv_buf);
                    g_ctrl.commitRecvBuffer(recv_buf,len);
                    break;
                    
                case 1: //data port

                    g_d.resetInfo();

                    /*==========================
                                         * thread for data TX
                                         * =========================
                                         */
                    new Thread(new Runnable() {
                        public void run() {

                            do {
                                try {
                                    Thread.sleep(100);
                                } catch (InterruptedException e) {

                                    break;
                                }
                                cmd = g_d.getCmd();
                                if(cmd.equals("send")) {
                                    tx.println(g_d.getTx());
                                    g_d.clearTx();
                                    g_d.clearCmd();
                                }

                            }while ( !cmd.equals("stop") );

                            if(!s.isClosed()) {
                                tx.close();
                                try {
                                    s.close();
                                } catch (IOException e) {
                                    Log.v(TAG_CTRL,"TX socket close  error");
                                }

                            }

                        }
                    }).start();

                    /*==========================
                                         * for data RX
                                         * =========================
                                         */
                    int b=0;
                    cmd = g_d.getCmd();
                    while (!cmd.equals("stop")) {
                        cmd = g_d.getCmd();

                        if( rx.available() > 0 ) {
                            while(rx.available() > 0)
                            {
                                b = rx.read();
                                cbuf.put((char) b);
                                cbuf.flip();
                                g_d.addInfo(cbuf.toString());
                                if(rx.available() == 0) {
                                    g_d.setReadable(true);
                                }
                            }

                        }else{
                            Thread.sleep(200);
                        }
                    }

                    break;
                default:
                    break;
            }
            
                rx.close();
                if(rx != null)
                    rx=null;

           }

            g_ctrl.clearCmd();
        }
        catch (Exception err)
        {
            Log.e(TAG,""+err);
        }
        
        
        try {
        	if(s != null)
        		if(!s.isClosed())                  
        			s.close();

        } catch (IOException e) {
            Log.e(TAG_CTRL,"TX socket close error");
        }
        return null;
    }

}