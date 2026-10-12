// ZAVERO POS - Professional Real-time Sound Effects & Uzbek Voice Notification System

(function() {
  let isVoiceEnabled = true;
  let playedOrderIds = new Set(); // Track announced orders to NEVER repeat the same order
  let speechQueue = [];          // Array of tasks: { orderId, text, onComplete }
  let isSpeaking = false;
  let audioContext = null;

  // Initialize or unlock AudioContext on user interaction
  function getAudioContext() {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!audioContext && AudioCtx) {
        audioContext = new AudioCtx();
      }
      if (audioContext && audioContext.state === 'suspended') {
        audioContext.resume();
      }
      return audioContext;
    } catch (_) {
      return null;
    }
  }

  // Audio Context Chime Synthesizer
  function playCrystalChime() {
    try {
      const ctx = getAudioContext();
      if (!ctx) return;
      const now = ctx.currentTime;

      // Note 1: High C6 (1046.50 Hz)
      const osc1 = ctx.createOscillator();
      const gain1 = ctx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(1046.50, now);
      osc1.frequency.exponentialRampToValueAtTime(1318.51, now + 0.08); // Slide to E6
      gain1.gain.setValueAtTime(0.4, now);
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.65);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(now);
      osc1.stop(now + 0.65);

      // Note 2: Crystal Chime C7 (2093.00 Hz)
      const osc2 = ctx.createOscillator();
      const gain2 = ctx.createGain();
      osc2.type = 'triangle';
      osc2.frequency.setValueAtTime(2093.00, now + 0.12);
      gain2.gain.setValueAtTime(0.35, now + 0.12);
      gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.9);
      osc2.connect(gain2);
      gain2.connect(ctx.destination);
      osc2.start(now + 0.12);
      osc2.stop(now + 0.9);
    } catch (e) {
      console.warn('AudioContext chime error:', e);
    }
  }

  // Find best clear male voice for Uzbek / Turkish / Russian / English TTS
  function getBestMaleVoice() {
    if (!('speechSynthesis' in window)) return null;
    const voices = window.speechSynthesis.getVoices() || [];
    if (!voices.length) return null;

    // 1. Explicit male names or descriptors
    let maleVoice = voices.find(v => {
      const n = (v.name || '').toLowerCase();
      const l = (v.lang || '').toLowerCase();
      const isMale = n.includes('male') || n.includes('david') || n.includes('george') || 
                     n.includes('yuri') || n.includes('dmitry') || n.includes('ahmet') || 
                     n.includes('alex') || n.includes('guy') || n.includes('daniel') || n.includes('pavel');
      return isMale && (l.startsWith('uz') || l.startsWith('tr') || l.startsWith('ru') || l.startsWith('en'));
    });
    if (maleVoice) return maleVoice;

    // 2. Direct Uzbek match
    let voice = voices.find(v => v.lang && (v.lang.toLowerCase().startsWith('uz') || v.lang.toLowerCase().includes('uzbek')));
    if (voice) return voice;

    // 3. High quality Turkish (phonetically closest to Uzbek)
    voice = voices.find(v => v.lang && v.lang.toLowerCase().startsWith('tr') && (v.name.includes('Natural') || v.name.includes('Google') || v.name.includes('Neural')));
    if (voice) return voice;

    voice = voices.find(v => v.lang && v.lang.toLowerCase().startsWith('tr'));
    if (voice) return voice;

    // 4. Russian Natural/Google voice
    voice = voices.find(v => v.lang && v.lang.toLowerCase().startsWith('ru') && (v.name.includes('Natural') || v.name.includes('Google') || v.name.includes('Yuri')));
    if (voice) return voice;

    return voices[0];
  }

  if ('speechSynthesis' in window) {
    window.speechSynthesis.onvoiceschanged = () => {
      getBestMaleVoice();
    };
  }

  // Speak a single sentence with clear, professional male voice parameters
  function speakSentence(text, onFinished) {
    if (!('speechSynthesis' in window) || !text) {
      if (onFinished) onFinished();
      return;
    }

    try {
      window.speechSynthesis.cancel(); // Stop any pending browser utter
    } catch (_) {}

    const utter = new SpeechSynthesisUtterance(text.trim());
    utter.rate = 0.95;  // Steady, clear, professional pacing
    utter.pitch = 0.88; // Masculine/baritone pitch for authoritative clear male sound
    utter.volume = 1.0;

    const voice = getBestMaleVoice();
    if (voice) {
      utter.voice = voice;
      utter.lang = voice.lang || 'uz-UZ';
    }

    let isFinished = false;
    const finishHandler = () => {
      if (isFinished) return;
      isFinished = true;
      if (onFinished) onFinished();
    };

    utter.onend = finishHandler;
    utter.onerror = (e) => {
      console.warn('Speech sentence error:', e);
      finishHandler();
    };

    try {
      window.speechSynthesis.speak(utter);
    } catch (err) {
      console.warn('Speech speak error:', err);
      finishHandler();
    }
  }

  let speechAudio = null;

  function playVoiceLabSpeechAudio(onFinished) {
    try {
      if (!speechAudio) {
        speechAudio = new Audio('voicelab-speech.wav');
        speechAudio.preload = 'auto';
      }
      speechAudio.currentTime = 0;
      speechAudio.onended = () => {
        if (onFinished) onFinished();
      };
      speechAudio.onerror = (e) => {
        console.warn('voicelab-speech.wav error, trying assets/audio/voicelab-speech.wav', e);
        try {
          const fallbackAudio = new Audio('assets/audio/voicelab-speech.wav');
          fallbackAudio.onended = () => { if (onFinished) onFinished(); };
          fallbackAudio.onerror = () => speakSentence("Mijozdan yangi buyurtma keldi.", onFinished);
          fallbackAudio.play().catch(() => speakSentence("Mijozdan yangi buyurtma keldi.", onFinished));
        } catch (_) {
          speakSentence("Mijozdan yangi buyurtma keldi.", onFinished);
        }
      };

      const playPromise = speechAudio.play();
      if (playPromise && playPromise.catch) {
        playPromise.catch((err) => {
          console.warn('Audio play rejected, attempting assets path or speech synthesis:', err);
          try {
            const fallbackAudio = new Audio('assets/audio/voicelab-speech.wav');
            fallbackAudio.onended = () => { if (onFinished) onFinished(); };
            fallbackAudio.play().catch(() => speakSentence("Mijozdan yangi buyurtma keldi.", onFinished));
          } catch (_) {
            speakSentence("Mijozdan yangi buyurtma keldi.", onFinished);
          }
        });
      }
    } catch (err) {
      console.warn('playVoiceLabSpeechAudio exception:', err);
      speakSentence("Mijozdan yangi buyurtma keldi.", onFinished);
    }
  }

  // Process Speech Queue sequentially (prevent overlapping speech)
  function processQueue() {
    if (isSpeaking || speechQueue.length === 0) return;
    if (!isVoiceEnabled) {
      speechQueue = [];
      return;
    }

    const task = speechQueue.shift();
    if (!task) return;

    isSpeaking = true;
    playCrystalChime();

    setTimeout(() => {
      playVoiceLabSpeechAudio(() => {
        isSpeaking = false;
        if (task.onComplete) task.onComplete();
        setTimeout(processQueue, 300);
      });
    }, 280);
  }

  // --- PUBLIC API EXPORTS ---

  // 1. Play general chime
  window.playChimeSound = function(type) {
    if (type === 'order' || type === 'qr_order') {
      playCrystalChime();
    } else {
      try {
        const ctx = getAudioContext();
        if (!ctx) return;
        const now = ctx.currentTime;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, now);
        osc.frequency.exponentialRampToValueAtTime(1760, now + 0.15);
        gain.gain.setValueAtTime(0.35, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.6);
      } catch (_) {}
    }
  };

  // 2. Announce new QR Order EXACTLY ONCE with male voice saying: "Mijozdan yangi buyurtma keldi."
  window.announceOrderVoice = function(orderId, speechText, reminderText, repeatIntervalSec) {
    if (!isVoiceEnabled) return;

    // Check if this order was already announced to NEVER repeat
    if (orderId && playedOrderIds.has(orderId)) {
      return;
    }
    if (orderId) {
      playedOrderIds.add(orderId);
    }

    // Exact required text
    const textToSpeak = "Mijozdan yangi buyurtma keldi.";

    speechQueue.push({
      orderId: orderId,
      text: textToSpeak,
      onComplete: () => {}
    });

    processQueue();
  };

  // 3. Stop voice
  window.stopOrderVoice = function(orderId) {
    speechQueue = speechQueue.filter(t => t.orderId !== orderId);
    if ('speechSynthesis' in window) {
      try {
        window.speechSynthesis.cancel();
      } catch (_) {}
    }
    isSpeaking = false;
    setTimeout(processQueue, 200);
  };

  // 4. Stop all voices
  window.stopAllOrderVoices = function() {
    speechQueue = [];
    if ('speechSynthesis' in window) {
      try {
        window.speechSynthesis.cancel();
      } catch (_) {}
    }
    isSpeaking = false;
  };

  // 5. Enable/disable voice
  window.setVoiceNotificationEnabled = function(enabled) {
    isVoiceEnabled = !!enabled;
    if (!isVoiceEnabled) {
      window.stopAllOrderVoices();
    }
  };

  // 6. Unlock Audio on user gesture
  window.unlockAudioNotification = function() {
    getAudioContext();
    if ('speechSynthesis' in window) {
      try {
        const dummy = new SpeechSynthesisUtterance('');
        dummy.volume = 0;
        window.speechSynthesis.speak(dummy);
      } catch (_) {}
    }
  };

  // Auto-listen to first user click to unlock web audio
  window.addEventListener('click', function onFirstClick() {
    window.unlockAudioNotification();
    window.removeEventListener('click', onFirstClick);
  }, { once: true });

})();
