package dev.sagron.zerotrustphone

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.InCallService
import android.telecom.VideoProfile
import android.view.Surface
import io.flutter.view.TextureRegistry

/**
 * Carrier video calls (ViLTE, P12). The carrier's IMS stack draws the
 * other person's video and the camera preview into two Flutter textures,
 * which the call screen shows. Video goes straight between the phone and
 * the carrier; nothing passes through ZT servers.
 */
object VideoSessions {
    private val main = Handler(Looper.getMainLooper())
    private val sessions = mutableMapOf<Call, Session>()

    /** The call screen engine's textures; null before it starts. */
    var textures: TextureRegistry? = null

    private class Texture(val entry: TextureRegistry.SurfaceTextureEntry) {
        val surface = Surface(entry.surfaceTexture())
        fun release() {
            surface.release()
            entry.release()
        }
    }

    private class Session(val call: Call) {
        var videoCall: InCallService.VideoCall? = null
        var display: Texture? = null
        var preview: Texture? = null
        var cameraId: String? = null
        var backCamera = false
        var peerWidth = 0
        var peerHeight = 0
        var previewWidth = 0
        var previewHeight = 0
        var request: VideoProfile? = null
        var wasVideo = false

        /** The user turned the camera off: only they turn it back on. */
        var cameraOffByUser = false

        val callback = object : InCallService.VideoCall.Callback() {
            override fun onSessionModifyRequestReceived(videoProfile: VideoProfile) {
                // The other person asks to turn video on, or to turn our
                // camera back on: that needs the user's yes.
                val asked = videoProfile.videoState
                val now = call.details.videoState
                val startsVideo = VideoProfile.isVideo(asked) && !VideoProfile.isVideo(now)
                val startsCamera = VideoProfile.isTransmissionEnabled(asked) &&
                    (!VideoProfile.isTransmissionEnabled(now) || cameraOffByUser)
                if (startsVideo || startsCamera) {
                    request = videoProfile
                    CallManager.notifyChanged()
                } else {
                    // Turning video off or pausing needs no answer from us.
                    videoCall?.sendSessionModifyResponse(videoProfile)
                }
            }

            override fun onSessionModifyResponseReceived(
                status: Int, requestedProfile: VideoProfile?, responseProfile: VideoProfile?
            ) {
                if (status != Connection.VideoProvider.SESSION_MODIFY_REQUEST_SUCCESS) {
                    CallManager.notice(call, "videoFailed")
                }
            }

            override fun onCallSessionEvent(event: Int) {}

            override fun onPeerDimensionsChanged(width: Int, height: Int) {
                peerWidth = width
                peerHeight = height
                display?.entry?.surfaceTexture()?.setDefaultBufferSize(width, height)
                CallManager.notifyChanged()
            }

            override fun onVideoQualityChanged(videoQuality: Int) {}

            override fun onCallDataUsageChanged(dataUsage: Long) {}

            override fun onCameraCapabilitiesChanged(
                cameraCapabilities: VideoProfile.CameraCapabilities
            ) {
                previewWidth = cameraCapabilities.width
                previewHeight = cameraCapabilities.height
                preview?.entry?.surfaceTexture()
                    ?.setDefaultBufferSize(previewWidth, previewHeight)
                CallManager.notifyChanged()
            }
        }
    }

    /** Keeps [call]'s surfaces and camera in step with its video state. */
    fun sync(context: Context?, call: Call) {
        val session = sessions.getOrPut(call) { Session(call) }
        val videoCall = call.videoCall
        if (videoCall !== session.videoCall) {
            session.videoCall?.unregisterCallback(session.callback)
            detach(session)
            session.videoCall = videoCall
            videoCall?.registerCallback(session.callback, main)
            videoCall?.setDeviceOrientation(0)
        }
        val vc = videoCall ?: return
        val state = call.details.videoState
        val live = call.stateCompat() in setOf(
            Call.STATE_DIALING, Call.STATE_CONNECTING, Call.STATE_ACTIVE
        )
        val receiving = live && VideoProfile.isReceptionEnabled(state)
        val sending = live && VideoProfile.isTransmissionEnabled(state) &&
            !VideoProfile.isPaused(state)

        if (receiving && session.display == null) {
            newTexture()?.let { t ->
                if (session.peerWidth > 0) {
                    t.entry.surfaceTexture().setDefaultBufferSize(session.peerWidth, session.peerHeight)
                }
                session.display = t
                vc.setDisplaySurface(t.surface)
            }
        } else if (!receiving && session.display != null) {
            vc.setDisplaySurface(null)
            session.display?.release()
            session.display = null
        }

        if (sending && !session.cameraOffByUser && session.cameraId == null &&
            context != null && cameraAllowed(context)
        ) {
            val front = cameraFacing(context, front = true)
            val camera = front ?: cameraFacing(context, front = false)
            val t = newTexture()
            if (camera != null && t != null) {
                session.preview = t
                session.cameraId = camera
                session.backCamera = front == null
                vc.setCamera(camera)
                vc.setPreviewSurface(t.surface)
                vc.requestCameraCapabilities()
            } else {
                t?.release()
            }
        } else if ((!sending || session.cameraOffByUser) && session.cameraId != null) {
            stopCamera(session)
        }

        val isVideo = live && VideoProfile.isVideo(state)
        if (isVideo && !session.wasVideo) {
            // Video calls use the speaker, like other dialers.
            if (CallManager.audioState?.route == CallAudioState.ROUTE_EARPIECE) {
                CallManager.setRoute(CallAudioState.ROUTE_SPEAKER)
            }
        }
        session.wasVideo = isVideo
        if (!live) session.request = null
    }

    fun remove(call: Call) {
        val session = sessions.remove(call) ?: return
        session.videoCall?.unregisterCallback(session.callback)
        detach(session)
    }

    private fun detach(session: Session) {
        val vc = session.videoCall
        if (session.cameraId != null) stopCamera(session)
        if (session.display != null) {
            vc?.setDisplaySurface(null)
            session.display?.release()
            session.display = null
        }
    }

    private fun stopCamera(session: Session) {
        session.videoCall?.setCamera(null)
        session.videoCall?.setPreviewSurface(null)
        session.preview?.release()
        session.preview = null
        session.cameraId = null
    }

    private fun newTexture(): Texture? = textures?.createSurfaceTexture()?.let { Texture(it) }

    private fun cameraAllowed(context: Context) =
        context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun cameraFacing(context: Context, front: Boolean): String? {
        val cameras = context.getSystemService(CameraManager::class.java) ?: return null
        val want = if (front) CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
        return try {
            cameras.cameraIdList.firstOrNull {
                cameras.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == want
            }
        } catch (_: Exception) {
            null
        }
    }

    /** What the call screen needs to draw [call]'s video. */
    fun describe(call: Call, context: Context?): Map<String, Any?> {
        val s = sessions[call]
        return mapOf(
            "videoState" to call.details.videoState,
            "displayTexture" to s?.display?.entry?.id(),
            "previewTexture" to s?.preview?.entry?.id(),
            "peerWidth" to (s?.peerWidth ?: 0),
            "peerHeight" to (s?.peerHeight ?: 0),
            "previewWidth" to (s?.previewWidth ?: 0),
            "previewHeight" to (s?.previewHeight ?: 0),
            "videoRequest" to (s?.request != null),
            "backCamera" to (s?.cameraId != null && s.backCamera),
            "cameraAllowed" to (context != null && cameraAllowed(context)),
        )
    }

    // Controls.

    /** Asks the carrier to turn video on ([send] false: only receive). */
    fun request(call: Call, send: Boolean = true) {
        sessions[call]?.cameraOffByUser = !send
        val vc = call.videoCall ?: return
        vc.sendSessionModifyRequest(
            VideoProfile(if (send) VideoProfile.STATE_BIDIRECTIONAL else VideoProfile.STATE_RX_ENABLED)
        )
    }

    /** Back to a voice call. The camera stops now, not when the carrier agrees. */
    fun stop(call: Call) {
        sessions[call]?.let {
            it.cameraOffByUser = true
            if (it.cameraId != null) stopCamera(it)
        }
        call.videoCall?.sendSessionModifyRequest(VideoProfile(VideoProfile.STATE_AUDIO_ONLY))
        CallManager.notifyChanged()
    }

    /**
     * Camera off keeps the other person's video coming. The camera stops
     * at once and stays off even if the carrier refuses the change.
     */
    fun setCameraOn(call: Call, on: Boolean) {
        sessions[call]?.let {
            it.cameraOffByUser = !on
            if (!on && it.cameraId != null) stopCamera(it)
        }
        val state = call.details.videoState
        val receiving = VideoProfile.isReceptionEnabled(state)
        val next = when {
            on && receiving -> VideoProfile.STATE_BIDIRECTIONAL
            on -> VideoProfile.STATE_TX_ENABLED
            receiving -> VideoProfile.STATE_RX_ENABLED
            else -> VideoProfile.STATE_AUDIO_ONLY
        }
        call.videoCall?.sendSessionModifyRequest(VideoProfile(next))
        CallManager.notifyChanged()
    }

    fun switchCamera(context: Context, call: Call) {
        val s = sessions[call] ?: return
        val vc = s.videoCall ?: return
        val current = s.cameraId ?: return
        val next = cameraFacing(context, front = s.backCamera) ?: return
        if (next == current) return
        s.cameraId = next
        s.backCamera = !s.backCamera
        vc.setCamera(next)
        vc.requestCameraCapabilities()
        CallManager.notifyChanged()
    }

    /** Answers the other person's request to turn video on. */
    fun respond(context: Context?, call: Call, accept: Boolean) {
        val s = sessions[call] ?: return
        val asked = s.request ?: return
        s.request = null
        if (accept) s.cameraOffByUser = false
        val keep = call.details.videoState
        val profile = when {
            // Declining keeps the call as it is (their video, our camera off).
            !accept -> VideoProfile(
                if (VideoProfile.isVideo(keep)) keep and VideoProfile.STATE_TX_ENABLED.inv()
                else VideoProfile.STATE_AUDIO_ONLY
            )
            context != null && cameraAllowed(context) -> asked
            // No camera permission: watch their video without sending ours.
            else -> VideoProfile(VideoProfile.STATE_RX_ENABLED)
        }
        s.videoCall?.sendSessionModifyResponse(profile)
        CallManager.notifyChanged()
    }
}
