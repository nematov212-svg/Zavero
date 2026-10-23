import React, { createContext, useContext, useState, useEffect } from 'react';
import { ambientMusic } from '../services/ambientMusic';

interface MusicContextType {
  isPlaying: boolean;
  toggleMusic: () => void;
  startMusic: () => void;
  stopMusic: () => void;
}

const MusicContext = createContext<MusicContextType | undefined>(undefined);

export const MusicProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isPlaying, setIsPlaying] = useState<boolean>(() => {
    return localStorage.getItem('zavero_music_muted') !== 'true';
  });

  const startMusic = async () => {
    const success = await ambientMusic.start();
    if (success) {
      setIsPlaying(true);
      localStorage.setItem('zavero_music_muted', 'false');
    }
  };

  const stopMusic = () => {
    ambientMusic.stop();
    setIsPlaying(false);
    localStorage.setItem('zavero_music_muted', 'true');
  };

  const toggleMusic = () => {
    if (isPlaying) {
      stopMusic();
    } else {
      startMusic();
    }
  };

  // Autoplay on site load: attempt immediate play and bind to first user interaction
  useEffect(() => {
    const isMuted = localStorage.getItem('zavero_music_muted') === 'true';
    if (isMuted) return;

    // 1. Try immediate auto-start
    ambientMusic.start().then((success) => {
      if (success) {
        setIsPlaying(true);
      }
    });

    // 2. Browser gesture unlocker: starts on first move, scroll, touch, or click
    const unlockAndPlay = () => {
      if (localStorage.getItem('zavero_music_muted') !== 'true' && !ambientMusic.getStatus()) {
        ambientMusic.start().then((success) => {
          if (success) setIsPlaying(true);
        });
      }
    };

    window.addEventListener('click', unlockAndPlay, { once: true });
    window.addEventListener('touchstart', unlockAndPlay, { once: true });
    window.addEventListener('scroll', unlockAndPlay, { once: true });
    window.addEventListener('mousemove', unlockAndPlay, { once: true });
    window.addEventListener('keydown', unlockAndPlay, { once: true });

    return () => {
      window.removeEventListener('click', unlockAndPlay);
      window.removeEventListener('touchstart', unlockAndPlay);
      window.removeEventListener('scroll', unlockAndPlay);
      window.removeEventListener('mousemove', unlockAndPlay);
      window.removeEventListener('keydown', unlockAndPlay);
    };
  }, []);

  return (
    <MusicContext.Provider value={{ isPlaying, toggleMusic, startMusic, stopMusic }}>
      {children}
    </MusicContext.Provider>
  );
};

export const useMusic = () => {
  const context = useContext(MusicContext);
  if (!context) {
    throw new Error('useMusic must be used within a MusicProvider');
  }
  return context;
};
