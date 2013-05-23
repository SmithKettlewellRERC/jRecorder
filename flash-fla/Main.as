package 
{
	import flash.display.Sprite;
	import flash.media.Microphone;
	import flash.system.SecurityPanel;
	import flash.system.Security;
	import org.bytearray.micrecorder.*;
	import org.bytearray.micrecorder.events.RecordingEvent;
	import org.bytearray.micrecorder.encoder.WaveEncoder;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.events.ActivityEvent;
	import fl.transitions.Tween;
	import fl.transitions.easing.Strong;
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.display.LoaderInfo;
	import flash.external.ExternalInterface;
	
	import flash.media.Sound;
	import org.as3wavsound.WavSound;
	import org.as3wavsound.WavSoundChannel;
	import flash.media.SoundChannel;

	public class Main extends Sprite
	{
		private var mic:Microphone;
		private var waveEncoder:WaveEncoder = new WaveEncoder();
		private var recorder:MicRecorder = new MicRecorder(waveEncoder);
		private var recBar:RecBar = new RecBar();
		
		private var maxTime:Number = 60;
		private var urlParams:Object = {};
		private var tween:Tween;
		private var fileReference:FileReference = new FileReference();
		
		private var tts:WavSound;
		private var soundChannel:WavSoundChannel;
		
		private var recording_loader:URLLoader;

		public function Main():void
		{ 
		
			trace('recording'); 

			mic = Microphone.getMicrophone();
			mic.setSilenceLevel(5);
			mic.gain = 50;
			mic.setLoopBack(false);
			mic.setUseEchoSuppression(true);
			
			addListeners();
		}

		private function addListeners():void
		{
			recorder.addEventListener(RecordingEvent.RECORDING, recording);
			recorder.addEventListener(Event.COMPLETE, recordComplete);
			stage.addEventListener(Event.ENTER_FRAME, updateMeter);
			 
			if( ExternalInterface.available )
			{ 
				//accept call from javascript to start recording
				ExternalInterface.addCallback("jStartRecording", jStartRecording);
				ExternalInterface.addCallback("jStopRecording", jStopRecording);
				ExternalInterface.addCallback("jSendFileToServer", jSendFileToServer);
				ExternalInterface.addCallback("jAddParameter", jAddParameter);
				ExternalInterface.addCallback("jRemoveParameter", jRemoveParameter);
				ExternalInterface.addCallback("jStartPreview", jStartPreview );
				ExternalInterface.addCallback("jStopPreview" , jStopPreview );
				
				ExternalInterface.call("jRecorderFlashInitialized" );
				ExternalInterface.call("$.jRecorder.log" , "ready!" );
			}			
		}
		
		//external java script function call to start record
		public function jStartRecording(max_time):void
		{
			maxTime = max_time;

			ExternalInterface.call("$.jRecorder.log" , "starting recording" );
			
			if (mic != null)
			{
				recorder.record();
				ExternalInterface.call("$.jRecorder.callback_started_recording");
				
			}
			else
			{
				ExternalInterface.call("$.jRecorder.callback_error_recording", 0);
			}
		}
		
		//external javascript function to trigger stop recording
		public function jStopRecording():void
		{
			recorder.stop();
			mic.setLoopBack(false);
			ExternalInterface.call("$.jRecorder.callback_stopped_recording");
		}
		
		public function jSendFileToServer():void
		{
			finalize_recording();	
		}
		
		public function jAddParameter(key,val):void
		{
			urlParams[key] = val;
		}
		
		public function jRemoveParameter(key):void
		{
			delete urlParams[key];
		}
		
		
		public function jStopPreview():void
		{
			// No function is currently available;
			if( soundChannel )
			{
				soundChannel.stop();
			}
		}

		public function jStartPreview():void
		{
			preview_recording();
		}
		

		private function updateMeter(e:Event):void
		{
			if( ExternalInterface.available )
			{
				ExternalInterface.call("$.jRecorder.callback_activityLevel",  mic.activityLevel);
			}
		}

		private function recording(e:RecordingEvent):void
		{
			var currentTime:int = Math.floor(e.time / 1000);

			if( ExternalInterface.available )
			{
				ExternalInterface.call("$.jRecorder.callback_activityTime",  String(currentTime) );
			}
			
			if(currentTime == maxTime )
			{
				jStopRecording();
			}
		}

		private function recordComplete(e:Event):void
		{
			
		}
		
		private function previewComplete( e:Event ):void
		{
			ExternalInterface.call("$.jRecorder.callback_preview_complete");
			stage.removeEventListener( Event.ENTER_FRAME , previewActivityTime );
		}
		
		private function previewActivityTime( e:Event ):void
		{
			//grab the position and volume from the soundChannel, then send it out through the external interface.
			ExternalInterface.call("$.jRecorder.callback_preview_activityTime", int(soundChannel.position/1000) , Number( soundChannel.leftPeak ) );
		}
		
		private function preview_recording():void
		{
			if( recorder.output )
			{
				tts = new WavSound(recorder.output);
				soundChannel = tts.play();
				soundChannel.addEventListener( Event.SOUND_COMPLETE , previewComplete );
				stage.addEventListener( Event.ENTER_FRAME , previewActivityTime );
				
				if( ExternalInterface.available )
				{
					ExternalInterface.call("$.jRecorder.callback_started_preview");
				}
			}
		}
		
		// Function to send data to server
		private function finalize_recording():void
		{
			var _var1:String= '';

			var globalParam = LoaderInfo(this.root.loaderInfo).parameters;

			for (var element:String in globalParam) {
				
					if (element == 'host')
					{
		   				_var1 = globalParam[element];
					}
			}

			if( ExternalInterface.available )
			{
				ExternalInterface.call("$.jRecorder.callback_finished_recording");
			}

			if(_var1 != '')
			{
				var key:String;
				var valuePairs:Array = new Array();
				for( key in this.urlParams )
				{
					if(urlParams.hasOwnProperty(key))
					{
						valuePairs.push( escape(key) + "=" + escape(urlParams[key]));
					}
				}

				_var1 += (_var1.indexOf("?") > -1 ? "&" : "?") + valuePairs.join("&");

				var req:URLRequest = new URLRequest(_var1);

				recording_loader = new URLLoader();
				recording_loader.addEventListener(Event.COMPLETE, postAudio_urlLoader_complete);

				req.data = recorder.output;
				req.contentType = 'application/octet-stream';
				req.method = URLRequestMethod.POST;

				recording_loader.load(req);
			}
			
		}
		
		private function postAudio_urlLoader_complete(evt:Event):void
		{			
			if( ExternalInterface.available )
			{
				ExternalInterface.call("jQuery.jRecorder.callback_finished_sending" , recording_loader.data );
			}
		}
		
		private function getFlashVars():Object
		{
			return Object( LoaderInfo( this.loaderInfo ).parameters );
		}
	}
}