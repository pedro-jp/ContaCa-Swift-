import React, { useState } from 'react';
import { ShieldAlert, ShieldCheck, Power, AlertTriangle } from 'lucide-react';

interface KillSwitchCardProps {
  isBlocked: boolean;
  onToggle: (newState: boolean) => Promise<void>;
}

export const KillSwitchCard: React.FC<KillSwitchCardProps> = ({ isBlocked, onToggle }) => {
  const [loading, setLoading] = useState(false);

  const handleToggleClick = async () => {
    setLoading(true);
    try {
      await onToggle(!isBlocked);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      className={`glass-card ${isBlocked ? 'killswitch-active' : ''}`}
      style={{
        padding: '24px',
        marginBottom: '28px',
        border: isBlocked ? '1px solid rgba(239, 68, 68, 0.6)' : '1px solid rgba(16, 185, 129, 0.3)',
        background: isBlocked 
          ? 'linear-gradient(135deg, rgba(40, 15, 20, 0.85) 0%, rgba(20, 10, 15, 0.8) 100%)' 
          : 'linear-gradient(135deg, rgba(15, 30, 25, 0.8) 0%, rgba(10, 20, 22, 0.75) 100%)'
      }}
    >
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '20px'
      }}>
        {/* Left Side: Status Icon & Details */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '18px' }}>
          <div style={{
            width: '56px',
            height: '56px',
            borderRadius: '16px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: isBlocked ? 'rgba(239, 68, 68, 0.2)' : 'rgba(16, 185, 129, 0.2)',
            color: isBlocked ? '#ef4444' : '#10b981',
            border: `1px solid ${isBlocked ? 'rgba(239, 68, 68, 0.4)' : 'rgba(16, 185, 129, 0.4)'}`,
            boxShadow: isBlocked ? '0 0 20px rgba(239, 68, 68, 0.3)' : '0 0 20px rgba(16, 185, 129, 0.2)'
          }}>
            {isBlocked ? <ShieldAlert size={30} /> : <ShieldCheck size={30} />}
          </div>

          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '4px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 800 }}>
                {isBlocked ? 'Bloqueio de Emergência Ativo (Kill-Switch)' : 'API de Inteligência Artificial Liberada'}
              </h3>
              <span style={{
                padding: '3px 10px',
                borderRadius: '999px',
                fontSize: '11px',
                fontWeight: 700,
                letterSpacing: '0.5px',
                textTransform: 'uppercase',
                backgroundColor: isBlocked ? 'rgba(239, 68, 68, 0.25)' : 'rgba(16, 185, 129, 0.2)',
                color: isBlocked ? '#f87171' : '#34d399',
                border: `1px solid ${isBlocked ? 'rgba(239, 68, 68, 0.4)' : 'rgba(16, 185, 129, 0.3)'}`
              }}>
                {isBlocked ? '⛔️ BLOQUEADO' : '🟢 OPERANTE'}
              </span>
            </div>

            <p style={{ fontSize: '13px', color: isBlocked ? '#fca5a5' : 'var(--text-secondary)', maxWidth: '600px' }}>
              {isBlocked
                ? 'Todas as requisições de IA vindas do aplicativo iOS/mobile são rejeitadas instantaneamente com HTTP 503 para proteger cotas e evitar custos. O motor local TACO offline continua operante.'
                : 'O proxy de IA está aberto para requisições de análise nutricional, treinos e diagnósticos de evolução do aplicativo mobile.'}
            </p>
          </div>
        </div>

        {/* Right Side: Toggle Button */}
        <div>
          <button
            onClick={handleToggleClick}
            disabled={loading}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: '14px 24px',
              borderRadius: '14px',
              fontWeight: 700,
              fontSize: '14px',
              border: 'none',
              color: '#fff',
              backgroundColor: isBlocked ? '#10b981' : '#ef4444',
              boxShadow: isBlocked 
                ? '0 4px 20px rgba(16, 185, 129, 0.4)' 
                : '0 4px 20px rgba(239, 68, 68, 0.4)',
            }}
          >
            <Power size={18} />
            <span>
              {loading 
                ? 'Atualizando...' 
                : (isBlocked ? 'Liberar Requisições à API' : 'Bloquear Requisições à API (Kill-Switch)')}
            </span>
          </button>
        </div>
      </div>
    </div>
  );
};
