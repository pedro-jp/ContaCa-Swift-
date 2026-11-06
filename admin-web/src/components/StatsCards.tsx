import React, { useEffect, useState } from 'react';
import { Users, Utensils, Dumbbell, Sparkles } from 'lucide-react';

interface StatsCardsProps {
  totalUsers: number;
  totalFoods: number;
  totalWorkouts: number;
  totalAiRequests: number;
  lastUpdatedKey?: string;
}

export const StatsCards: React.FC<StatsCardsProps> = ({
  totalUsers,
  totalFoods,
  totalWorkouts,
  totalAiRequests,
  lastUpdatedKey
}) => {
  const [flashCard, setFlashCard] = useState<string | null>(null);

  useEffect(() => {
    if (lastUpdatedKey) {
      setFlashCard(lastUpdatedKey);
      const timer = setTimeout(() => setFlashCard(null), 1200);
      return () => clearTimeout(timer);
    }
  }, [lastUpdatedKey, totalUsers, totalFoods, totalWorkouts, totalAiRequests]);

  const cards = [
    {
      id: 'users',
      label: 'Usuários Cadastrados',
      value: totalUsers,
      sub: 'Sincronizados no Supabase',
      icon: <Users size={24} />,
      color: '#3b82f6',
      bgIcon: 'rgba(59, 130, 246, 0.15)'
    },
    {
      id: 'foods',
      label: 'Alimentos Registrados',
      value: totalFoods,
      sub: 'Refeições salvas na nuvem',
      icon: <Utensils size={24} />,
      color: '#10b981',
      bgIcon: 'rgba(16, 185, 129, 0.15)'
    },
    {
      id: 'workouts',
      label: 'Treinos Realizados',
      value: totalWorkouts,
      sub: 'Musculação e aeróbicos',
      icon: <Dumbbell size={24} />,
      color: '#f59e0b',
      bgIcon: 'rgba(245, 158, 11, 0.15)'
    },
    {
      id: 'ai',
      label: 'Requisições de IA',
      value: totalAiRequests,
      sub: 'Pelo proxy backend seguro',
      icon: <Sparkles size={24} />,
      color: '#8b5cf6',
      bgIcon: 'rgba(139, 92, 246, 0.15)'
    }
  ];

  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
      gap: '20px',
      marginBottom: '28px'
    }}>
      {cards.map((c) => {
        const isFlashing = flashCard === c.id;
        return (
          <div
            key={c.id}
            className={`glass-card ${isFlashing ? 'flash-updated' : ''}`}
            style={{
              padding: '22px',
              display: 'flex',
              alignItems: 'center',
              gap: '18px',
              border: isFlashing ? `1px solid ${c.color}` : '1px solid var(--border-color)',
              transition: 'all 0.3s ease'
            }}
          >
            <div style={{
              width: '50px',
              height: '50px',
              borderRadius: '14px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: c.bgIcon,
              color: c.color,
              flexShrink: 0
            }}>
              {c.icon}
            </div>

            <div>
              <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-secondary)', display: 'block' }}>
                {c.label}
              </span>
              <div style={{ fontSize: '28px', fontWeight: 800, letterSpacing: '-0.5px', margin: '2px 0' }}>
                {c.value.toLocaleString('pt-BR')}
              </div>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                {c.sub}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
};
