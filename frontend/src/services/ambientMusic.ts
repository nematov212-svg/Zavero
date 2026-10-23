/**
 * Zavero Luxury Cafe & Lounge Ambient Audio Engine
 * Uses Web Audio API: Zero external dependencies, 100% offline-ready, zero lag,
 * generates lush, relaxing cafe/lounge ambient music with warm Rhodes piano tones and stereo space.
 */

class AmbientMusicEngine {
  private ctx: AudioContext | null = null;
  private isRunning: boolean = false;
  private masterGain: GainNode | null = null;
  private delayNode: DelayNode | null = null;
  private feedbackGain: GainNode | null = null;
  private sequenceTimer: any = null;
  private chimeTimer: any = null;
  private currentChordIndex: number = 0;

  // Lush, heartwarming luxury cafe chord progression (frequencies in Hz)
  // Dmaj9 -> Bm9 -> Gmaj7 -> Asus4/A
  private chords: { root: number; freqs: number[]; chimes: number[] }[] = [
    {
      root: 146.83, // D3
      freqs: [220.0, 293.66, 369.99, 440.0, 554.37], // A3, D4, F#4, A4, C#5 (Dmaj9)
      chimes: [587.33, 739.99, 880.0, 1108.73], // D5, F#5, A5, C#6
    },
    {
      root: 123.47, // B2
      freqs: [220.0, 293.66, 369.99, 440.0, 493.88], // A3, D4, F#4, A4, B4 (Bm9)
      chimes: [493.88, 587.33, 739.99, 880.0], // B4, D5, F#5, A5
    },
    {
      root: 98.0, // G2
      freqs: [196.0, 293.66, 369.99, 392.0, 440.0], // G3, D4, F#4, G4, A4 (Gmaj7)
      chimes: [587.33, 783.99, 880.0, 987.77], // D5, G5, A5, B5
    },
    {
      root: 110.0, // A2
      freqs: [220.0, 293.66, 329.63, 440.0, 554.37], // A3, D4, E4, A4, C#5 (Asus4/A)
      chimes: [659.25, 739.99, 880.0, 1108.73], // E5, F#5, A5, C#6
    },
  ];

  private initContext() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();

        // Master Gain
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.setValueAtTime(0.0001, this.ctx.currentTime);

        // Ambient Stereo Delay (Reverb-like spatial dimension)
        this.delayNode = this.ctx.createDelay(1.5);
        this.delayNode.delayTime.value = 0.38;

        this.feedbackGain = this.ctx.createGain();
        this.feedbackGain.gain.value = 0.28;

        // Delay feedback loop
        this.delayNode.connect(this.feedbackGain);
        this.feedbackGain.connect(this.delayNode);

        // Route master and delay to destination
        this.delayNode.connect(this.ctx.destination);
        this.masterGain.connect(this.ctx.destination);
        this.masterGain.connect(this.delayNode);
      }
    }

    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
  }

  /**
   * Warm piano / electric keyboard pad generator
   */
  private playWarmNote(freq: number, startTime: number, duration: number, gainVal: number) {
    if (!this.ctx || !this.masterGain) return;

    try {
      // Primary soft sine
      const osc1 = this.ctx.createOscillator();
      const osc2 = this.ctx.createOscillator();
      const noteGain = this.ctx.createGain();
      const filter = this.ctx.createBiquadFilter();

      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(freq, startTime);

      // Subtle warm detuned harmonic
      osc2.type = 'triangle';
      osc2.frequency.setValueAtTime(freq * 1.002, startTime);

      // Warm low-pass filter (gentle jazz sound)
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(800, startTime);
      filter.Q.value = 1.0;

      // Soft envelope
      noteGain.gain.setValueAtTime(0.0001, startTime);
      noteGain.gain.exponentialRampToValueAtTime(gainVal, startTime + 0.9);
      noteGain.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);

      osc1.connect(filter);
      osc2.connect(filter);
      filter.connect(noteGain);
      noteGain.connect(this.masterGain);

      osc1.start(startTime);
      osc2.start(startTime);
      osc1.stop(startTime + duration + 0.2);
      osc2.stop(startTime + duration + 0.2);
    } catch (e) {
      // Ignore
    }
  }

  /**
   * Delicate acoustic sparkle chime
   */
  private playChime(freq: number, startTime: number) {
    if (!this.ctx || !this.masterGain) return;

    try {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, startTime);

      gain.gain.setValueAtTime(0.0001, startTime);
      gain.gain.exponentialRampToValueAtTime(0.015, startTime + 0.05);
      gain.gain.exponentialRampToValueAtTime(0.0001, startTime + 2.5);

      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(startTime);
      osc.stop(startTime + 2.6);
    } catch (e) {
      // Ignore
    }
  }

  private stepChord() {
    if (!this.ctx || !this.isRunning) return;

    const chord = this.chords[this.currentChordIndex];
    this.currentChordIndex = (this.currentChordIndex + 1) % this.chords.length;

    const now = this.ctx.currentTime;
    const chordDuration = 5.0;

    // Deep warm root bass
    this.playWarmNote(chord.root, now, chordDuration + 0.5, 0.045);

    // Beautiful harmonic body notes
    chord.freqs.forEach((freq, idx) => {
      const delay = idx * 0.14;
      this.playWarmNote(freq, now + delay, chordDuration, 0.025);
    });

    // Random soothing chimes (like relaxing cafe chimes)
    const randomChime = chord.chimes[Math.floor(Math.random() * chord.chimes.length)];
    this.playChime(randomChime, now + 1.2);

    const secondChime = chord.chimes[Math.floor(Math.random() * chord.chimes.length)];
    this.playChime(secondChime, now + 2.8);

    // Schedule next chord
    this.sequenceTimer = setTimeout(() => {
      if (this.isRunning) {
        this.stepChord();
      }
    }, (chordDuration - 0.4) * 1000);
  }

  public async start(): Promise<boolean> {
    try {
      this.initContext();
      if (!this.ctx || !this.masterGain) return false;

      if (this.ctx.state === 'suspended') {
        await this.ctx.resume();
      }

      this.isRunning = true;

      // Smooth, velvet fade-in
      const now = this.ctx.currentTime;
      this.masterGain.gain.cancelScheduledValues(now);
      this.masterGain.gain.setValueAtTime(this.masterGain.gain.value || 0.0001, now);
      this.masterGain.gain.exponentialRampToValueAtTime(0.24, now + 2.0);

      this.stepChord();
      return true;
    } catch (err) {
      console.warn('Browser waiting for first interaction to unlock audio:', err);
      return false;
    }
  }

  public stop() {
    this.isRunning = false;
    if (this.sequenceTimer) {
      clearTimeout(this.sequenceTimer);
      this.sequenceTimer = null;
    }
    if (this.chimeTimer) {
      clearTimeout(this.chimeTimer);
      this.chimeTimer = null;
    }
    if (this.ctx && this.masterGain) {
      try {
        const now = this.ctx.currentTime;
        this.masterGain.gain.cancelScheduledValues(now);
        this.masterGain.gain.setValueAtTime(this.masterGain.gain.value, now);
        this.masterGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.6);
      } catch (e) {
        // Ignore
      }
    }
  }

  public getStatus(): boolean {
    return this.isRunning;
  }
}

export const ambientMusic = new AmbientMusicEngine();
