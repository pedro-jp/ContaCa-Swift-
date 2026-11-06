import React from 'react';
import { Activity, Clock, User, Zap, AlertTriangle, CheckCircle } from 'lucide-react';
import { AiLogSummary } from '../types';

interface LiveActivityFeedProps {
  logs: AiLogSummary[];
  connectedClientsCount: number;
}

export const LiveActivityFeed: React.FC<LiveActivityFeedProps> = ({ logs, connectedClientsCount }) => {
  return (
    <div className="glass-card" style={{ padding: '24px', marginBottom: '28px' }}>
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '12px',
        marginBottom: '20px',
        paddingBottom: '16px',
        borderBottom: '1px solid var(--border-color)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '12px',
            backgroundColor: 'rgba(139, 92, 246, 0.15)',
            color: '#a78bfa',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <Activity size={22} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 800 }}>Feed de Requisições &amp; Telemetria em Tempo Real</h3>
              <span className="live-pulse" style={{
                display: 'inline-block',
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                backgroundColor: '#10b981',
                boxShadow: '0 0 8px #10b981'
              }} />
            </div>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Cada requisição feita pelo aplicativo mobile surge instantaneamente via WebSocket sem recarregar a página.
            </p>
          </div>
        </div>

        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          fontSize: '12px',
          color: 'var(--text-muted)',
          backgroundColor: 'rgba(0, 0, 0, 0.3)',
          padding: '6px 14px',
          borderRadius: '999px',
          border: '1px solid var(--border-color)'
        }}>
          <Zap size={14} color="#10b981" />
          <span>Sessão WebSocket Ativa</span>
        </div>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px', textAlign: 'left' }}>
          <thead>
            <tr style={{ color: 'var(--text-muted)', borderBottom: '1px solid var(--border-color)' }}>
              <th style={{ padding: '12px 14px', fontWeight: 600 }}>Horário</th>
              <th style={{ padding: '12px 14px', fontWeight: 600 }}>Endpoint</th>
              <th style={{ padding: '12px 14px', fontWeight: 600 }}>Descrição / Prompt</th>
              <th style={{ padding: '12px 14px', fontWeight: 600 }}>Status</th>
              <th style={{ padding: '12px 14px', fontWeight: 600 }}>Latência</th>
            </tr>
          </thead>
          <tbody>
            {logs.length === 0 ? (
              <tr>
                <td colSpan={5} style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  Aguardando requisições em tempo real... Abra o app e faça uma leitura nutricional ou treino.
                </td>
              </tr>
            ) : (
              logs.slice(0, 30).map((log, index) => {
                const isSuccess = log.status === 'SUCCESS';
                const isBlocked = log.status?.includes('BLOQUEADAS') || log.status?.includes('BLOCKED');
                const timeStr = log.createdAt ? new Date(log.createdAt).toLocaleTimeString('pt-BR') : '--:--:--';

                return (
                  <tr
                    key={log.id || index}
                    style={{
                      borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
                      backgroundColor: index === 0 ? 'rgba(16, 185, 129, 0.04)' : 'transparent',
                      transition: 'background-color 0.2s ease'
                    }}
                  >
                    <td style={{ padding: '12px 14px', whiteSpace: 'nowrap' }} className="font-mono">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-secondary)' }}>
                        <Clock size={12} />
                        <span>{timeStr}</span>
                      </div>
                    </td>
                    <td style={{ padding: '12px 14px', whiteSpace: 'nowrap' }}>
                      <span className="font-mono" style={{
                        backgroundColor: 'rgba(255, 255, 255, 0.06)',
                        padding: '3px 8px',
                        borderRadius: '6px',
                        fontSize: '12px',
                        color: '#93c5fd'
                      }}>
                        {log.endpoint || '/api/ai/*'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 14px', maxWidth: '320px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      <span title={log.promptSummary} style={{ color: '#e2e8f0' }}>
                        {log.promptSummary || '(Sem descrição)'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 14px', whiteSpace: 'nowrap' }}>
                      <span style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '4px',
                        padding: '3px 10px',
                        borderRadius: '999px',
                        fontSize: '11px',
                        fontWeight: 700,
                        backgroundColor: isSuccess 
                          ? 'rgba(16, 185, 129, 0.15)' 
                          : (isBlocked ? 'rgba(245, 158, 11, 0.15)' : 'rgba(239, 68, 68, 0.15)'),
                        color: isSuccess ? '#34d399' : (isBlocked ? '#fbbf24' : '#f87171'),
                        border: `1px solid ${isSuccess ? 'rgba(16, 185, 129, 0.3)' : (isBlocked ? 'rgba(245, 158, 11, 0.3)' : 'rgba(239, 68, 68, 0.3)')}`
                      }}>
                        {isSuccess ? <CheckCircle size={10} /> : <AlertTriangle size={10} />}
                        <span>{log.status || 'OK'}</span>
                      </span>
                    </td>
                    <td style={{ padding: '12px 14px', whiteSpace: 'nowrap' }} className="font-mono">
                      <span style={{ color: log.durationMs > 5000 ? '#fbbf24' : '#94a3b8', fontSize: '12px' }}>
                        {log.durationMs != null ? `${log.durationMs}ms` : '--'}
                      </span>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
