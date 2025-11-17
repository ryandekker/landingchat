/**
 * Radar chart component for displaying understanding dimensions
 */

import { RadarChart as RechartsRadar, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar, ResponsiveContainer } from 'recharts';
import type { RadarDimension } from '@landingchat/shared';

interface RadarChartProps {
  dimensions: RadarDimension[];
}

export function RadarChart({ dimensions }: RadarChartProps) {
  if (!dimensions || dimensions.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-400">
        <p>No data yet...</p>
      </div>
    );
  }

  const data = dimensions.map(dim => ({
    dimension: dim.label,
    score: dim.score,
    fullMark: 100
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <RechartsRadar data={data}>
        <PolarGrid />
        <PolarAngleAxis dataKey="dimension" />
        <PolarRadiusAxis angle={90} domain={[0, 100]} />
        <Radar
          name="Understanding"
          dataKey="score"
          stroke="#0ea5e9"
          fill="#0ea5e9"
          fillOpacity={0.6}
        />
      </RechartsRadar>
    </ResponsiveContainer>
  );
}
