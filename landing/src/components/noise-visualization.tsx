'use client';

import { useEffect, useState } from 'react';

const NoiseVisualization = () => {
  const [bars, setBars] = useState([1, 0.7, 1.2, 0.9, 1.5]);

  useEffect(() => {
    const interval = setInterval(() => {
      setBars(prev => prev.map(() => 0.5 + Math.random() * 1.5));
    }, 2000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex items-end justify-center space-x-1 h-16 w-20">
      {bars.map((height, index) => (
        <div
          key={index}
          className="bg-gradient-to-t from-warn-600 to-warn-400 rounded-t-sm noise-bar transition-all duration-300"
          style={{
            height: `${height * 60}%`,
            width: '8px',
            animationDelay: `${index * 0.2}s`,
          }}
        />
      ))}
    </div>
  );
};

export default NoiseVisualization;