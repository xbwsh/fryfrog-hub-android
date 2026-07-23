package com.fryfrog.hub.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Parcel
import android.os.RemoteException
import android.util.Log

/**
 * 小米澎湃OS公平运行内存机制适配
 * 监听内存预警(TRIM)和异常查杀(KILL)广播
 */
class MemoryWatchdogReceiver : IBinder.DeathRecipient {

    companion object {
        private const val TAG = "MemoryWatchdog"
        private const val ITGSA_ACTION = "itgsa.intent.action.TRIM"
        const val TRANSACTION_EXCEPTION_REPLY = IBinder.FIRST_CALL_TRANSACTION
    }

    private var mRemote: IBinder? = null
    private var mInitialized = false
    private var mHandler: Handler? = null

    @Volatile
    private var instance: MemoryWatchdogReceiver? = null

    fun getInstance(): MemoryWatchdogReceiver {
        return instance ?: synchronized(this) {
            instance ?: MemoryWatchdogReceiver().also { instance = it }
        }
    }

    override fun binderDied() {
        synchronized(this) {
            mRemote?.let { binder ->
                try {
                    binder.unlinkToDeath(this, 0)
                } catch (ignore: Exception) {}
            }
            mRemote = null
        }
    }

    fun initialize(context: Context) {
        synchronized(this) {
            if (!mInitialized) {
                val handlerThread = android.os.HandlerThread(TAG)
                handlerThread.start()
                mHandler = Handler(handlerThread.looper)

                val filter = IntentFilter(ITGSA_ACTION)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    context.registerReceiver(mReceiver, filter, null, mHandler, Context.RECEIVER_EXPORTED)
                } else {
                    context.registerReceiver(mReceiver, filter, null, mHandler)
                }

                mInitialized = true
                Log.d(TAG, "MemoryWatchdog initialized")
            }
        }
    }

    private val mReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ITGSA_ACTION == intent.action) {
                val data = intent.extras ?: return

                // 获取公共数据
                val bundle = data.getBundle("common") ?: return
                val notifyType = bundle.getInt("notifyType")
                val notifyId = bundle.getInt("notifyId")
                val reason = bundle.getString("reason")
                val action = bundle.getString("action")
                val callbackBinder = bundle.getBinder("callback")

                // 获取额外数据
                val extraData = data.getBundle("extra")

                Log.d(TAG, "Received memory event: type=$notifyType, id=$notifyId, reason=$reason, action=$action")

                // 根据不同类型处理
                when (notifyType) {
                    1000 -> {
                        // 物理内存异常
                        val pss = extraData?.getInt("pss") ?: 0
                        val pssLimit = extraData?.getInt("pssLimit") ?: 0
                        Log.w(TAG, "Physical memory warning: PSS=$pss, limit=$pssLimit")
                        handleMemoryWarning(notifyType, notifyId, callbackBinder, pss, pssLimit)
                    }
                    2000 -> {
                        // Java堆内存异常
                        val heapAlloc = extraData?.getInt("heapAlloc") ?: 0
                        val heapCapacity = extraData?.getInt("heapCapacity") ?: 0
                        Log.w(TAG, "Java heap warning: allocated=$heapAlloc, capacity=$heapCapacity")
                        handleMemoryWarning(notifyType, notifyId, callbackBinder, heapAlloc, heapCapacity)
                    }
                    else -> {
                        Log.d(TAG, "Unknown notify type: $notifyType")
                    }
                }
            }
        }
    }

    private fun handleMemoryWarning(notifyType: Int, notifyId: Int, callback: IBinder?, vararg args: Int) {
        // 清理内存缓存
        releaseMemory()

        // 回调系统
        if (callback != null) {
            checkRemote(callback)
            val extra = Bundle()
            extra.putString("reply", "memory released")
            reply(notifyType, notifyId, 0, extra) // result=0 表示成功处理
        }
    }

    private fun releaseMemory() {
        // 1. 清理图片缓存
        // 2. 释放大对象
        // 3. 清理业务缓存
        Log.d(TAG, "Releasing memory resources...")
        
        // 触发系统内存清理
        Runtime.getRuntime().gc()
    }

    private fun checkRemote(callback: IBinder): Boolean {
        synchronized(this) {
            if (mRemote == null) {
                try {
                    mRemote = callback
                    mRemote?.linkToDeath(this, 0)
                } catch (e: RemoteException) {
                    mRemote = null
                    return false
                }
            }
        }
        return true
    }

    fun reply(notifyType: Int, notifyId: Int, result: Int, extra: Bundle?) {
        synchronized(this) {
            val remote = mRemote ?: return
            val data = Parcel.obtain()
            val reply = Parcel.obtain()
            try {
                data.writeInt(notifyType)
                data.writeInt(notifyId)
                data.writeInt(result)
                val bundle = extra ?: Bundle()
                data.writeBundle(bundle)
                remote.transact(TRANSACTION_EXCEPTION_REPLY, data, reply, IBinder.FLAG_ONEWAY)
                reply.readException()
            } catch (e: Exception) {
                Log.e(TAG, "reply failed.", e)
            } finally {
                reply.recycle()
                data.recycle()
            }
        }
    }

    fun destroy() {
        synchronized(this) {
            mRemote?.let { binder ->
                try {
                    binder.unlinkToDeath(this, 0)
                } catch (ignore: Exception) {}
            }
            mRemote = null
            mInitialized = false
            instance = null
        }
    }
}
