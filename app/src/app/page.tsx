'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';
import { GeoMap } from '@/components/GeoMap';
import { ArchitectureDiagram } from '@/components/ArchitectureDiagram';

interface DemoNarrative {
  title: string;
  duration: string;
  thesis: string;
  tabs: any[];
}

export default function HomePage() {
  const [narrative, setNarrative] = useState<DemoNarrative | null>(null);
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    fetch('/demo_narrative.json')
      .then((r) => r.json())
      .then(setNarrative)
      .catch(() => {});
    fetch('/api/data')
      .then((r) => r.json())
      .then(setData)
      .catch(() => {});
  }, []);


  // KPI values come from /api/data, which reads CURATED.KPI_SUMMARY. The literal
  // stays as a fallback so the card still renders if the API is unavailable.
  const kpiVal = (title: string, fallback: string): string =>
    (data?.kpiCards as { title: string; value: string }[] | undefined)
      ?.find((k) => k.title === title)?.value ?? fallback;

  const title = narrative?.title || 'SEA AWS Demo';

  const executiveCockpit = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Policies Active" value={kpiVal('Policies Active', '8.4M')} status="neutral" />
        <KPICard title="Claims Ratio" value={kpiVal('Claims Ratio', '42%')} status="neutral" />
        <KPICard title="Premium Income" value={kpiVal('Premium Income', 'PHP 2.1B')} status="neutral" />
        <KPICard title="Inclusion Reach" value={kpiVal('Inclusion Reach', '+1.2M')} status="neutral" />
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="lg:col-span-1">
          <GeoMap country="philippines" markers={[{"label": "Manila", "value": "HQ: 247 branches", "color": "blue", "size": "lg"}, {"label": "Cebu", "value": "Visayas: 84 branches", "color": "green", "size": "md"}, {"label": "Davao", "value": "Mindanao: 42", "color": "green", "size": "md"}]} routes={[]} title="Geographic Overview" height={400} />
        </div>
        <div className="lg:col-span-1 grid grid-cols-1 gap-4">
          <Chart data={data?.timeseries || [{ period: 'Jan', value: 112 }, { period: 'Feb', value: 118 }, { period: 'Mar', value: 135 }, { period: 'Apr', value: 148 }, { period: 'May', value: 156 }, { period: 'Jun', value: 142 }, { period: 'Jul', value: 138 }, { period: 'Aug', value: 151 }, { period: 'Sep', value: 144 }, { period: 'Oct', value: 132 }, { period: 'Nov', value: 121 }, { period: 'Dec', value: 115 }]} type="line" xKey="period" yKeys={[{ key: 'value', name: 'Policies (M)' }]} title="Policy Growth (Monthly)" />
          <Chart data={data?.categories || [{ category: 'North', count: 82 }, { category: 'Central', count: 74 }, { category: 'South', count: 91 }, { category: 'Highland', count: 68 }, { category: 'Coastal', count: 77 }]} type="bar" xKey="category" yKeys={[{ key: 'count', name: 'PHP M' }]} title="Claims by Product" />
        </div>
      </div>
      <DataTable columns={[
          { key: 'id', header: '#' },
          { key: 'name', header: 'Product' },
          { key: 'status', header: 'Profitability' },
          { key: 'value', header: 'Policies (K)' },
      ]} data={data?.entities || []} title="Product Performance" />
    </div>
  );

  const domainTab1 = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Agent Network" value={kpiVal('Agent Network', '42K')} />
        <KPICard title="Digital Enrollment" value={kpiVal('Digital Enrollment', '34%')} />
        <KPICard title="Renewal Rate" value={kpiVal('Renewal Rate', '78%')} />
      </div>
      <Chart data={data?.detail || [{ x: 'Mon', y: 24 }, { x: 'Tue', y: 28 }, { x: 'Wed', y: 22 }, { x: 'Thu', y: 31 }, { x: 'Fri', y: 26 }, { x: 'Sat', y: 19 }, { x: 'Sun', y: 23 }]} type="area" xKey="x" yKeys={[{ key: 'y', name: 'Policies (K)' }]} title="Distribution Channel Mix" height={400} />
    </div>
  );

  const domainTab2 = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.breakdown || [{ label: 'Zone North', value: 35 }, { label: 'Zone Central', value: 28 }, { label: 'Zone South', value: 22 }, { label: 'Zone East', value: 15 }]} type="pie" xKey="label" yKeys={[{ key: 'value', name: 'Loss %' }]} title="Loss Ratio by Province" />
        <ActionMemo persona={{ name: 'Ana Marie Villanueva', role: 'VP Microinsurance' }} context={{}} onGenerate={async () => ({ subject: 'Action Required', body: 'AI-generated recommendation based on current data.', urgency: 'HIGH', actions: ['Launch typhoon parametric insurance for Visayas', 'Expand digital claims for motorcycle product', 'Partner with DSWD for bundled insurance'] })} />
      </div>
    </div>
  );

  const askAiTab = (
    <div className="h-[600px]">
      <AskAI title="Ask AI" mode="sql" sampleQuestions={['Which provinces have the highest claims ratio?', 'Show typhoon correlation with claims', 'What is the optimal agricultural premium?']} onSubmit={async (question, mode) => ({ answer: `[Demo Mode] Response to: "${question}" (${mode} mode). Connect to Snowflake for live data.`, sql: mode === 'sql' ? 'SELECT * FROM CURATED.SUMMARY LIMIT 10;' : undefined })} />
    </div>
  );

  const architectureTab = (
    <ArchitectureDiagram
      snowflakeFeatures={['Dynamic Tables (5-min refresh)', 'ML Functions (Forecast + Anomaly)', 'Cortex Search + Agent', 'Semantic View + Intelligence']}
      awsServices={[{ name: 'Amazon S3', role: 'Strategy Docs' }, { name: 'Amazon S3 + Kinesis', role: 'Integration' }, { name: 'Amazon SNS', role: 'Integration' }, { name: 'Amazon QuickSight + Q', role: 'Integration' }]}
    />
  );

  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '📊', content: executiveCockpit },
    { id: 'domain-1', label: 'Distribution', icon: '📈', content: domainTab1 },
    { id: 'domain-2', label: 'Claims & Risk', icon: '⚡', content: domainTab2 },
    { id: 'ask-ai', label: 'Ask AI', icon: '🤖', content: askAiTab },
    { id: 'architecture', label: 'Architecture', icon: '🏗️', content: architectureTab },
  ];

  return <AppLayout title={title} tabs={tabs} narrative={narrative} />;
}
