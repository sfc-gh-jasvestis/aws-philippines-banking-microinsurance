'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface MicroinsuranceData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; exceptions: number | null; failed: number | null }[];
  categories: { category: string; exceptions: number | null; failed: number | null }[];
  entities: Record<string, string | number | null>[];
  reconRisk: { name: string; compliance: number; failed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; exceptions: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<MicroinsuranceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Claims per 1,000 Premium Payments', 'Claims Notified', 'Escalated to Claims Investigation', 'Premium Value (PHP M)'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Claims per 1,000 premium payments = claims notified x 1,000 / premium payments received. Escalation rate = claims escalated to claims investigation / claims. Premium value is the PHP value of all premium payments received in the snapshot.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'exceptions', name: 'Claims' }, { key: 'failed', name: 'Escalated' }]} title="Daily Claims Notified" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'exceptions', name: 'Claims' }, { key: 'failed', name: 'Escalated' }]} title="Claims Notified and Escalations by Claim Cause" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Plan' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Microinsurance product' },
        { key: 'tier', header: 'Risk grade' }, { key: 'payments', header: 'Premium payments' }, { key: 'exceptions', header: 'Claims' },
        { key: 'failed', header: 'Escalated' }, { key: 'breaches', header: 'Settlement SLA breaches' }, { key: 'value', header: 'Value (PHP M)' },
      ]} data={data?.entities ?? []} title="Plan observations (all plans are written in the Philippines)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day claims escalation risk and claims-volume forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a plan has a claim escalated to claims investigation in the next 7 days,
        from the claim document rejection rate, average days to settle, recent escalations, insured member risk grade, plan age and microinsurance product.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} plan-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Plan' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(escalation in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Claims escalation risk by plan" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Portfolio-wide claims forecast, next 14 days (claims per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Plan' }, { key: 'date', header: 'Date' }, { key: 'screening', header: 'Claim document rejection rate (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Claim document rejection rate anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live claims: Amazon Data Firehose to S3 to Snowpipe' : 'Live claims: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated claim events are sent to the Firehose stream ph-banking-microinsurance-claims (aws/publish_claims.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_CLAIMS.'
          : 'CALL APP.SIMULATE_CLAIMS(n) inserts simulated claim events directly into RAW.LIVE_CLAIMS (or resume APP.TASK_SIMULATE_CLAIMS for a feed every minute). This simulates a claim feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_CLAIMS_ALERT logs REFERRED claims and emails the on-call claims officer.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Claim events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="REFERRED claims" value={String(data?.liveSummary?.exceptions ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Plan' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Amount (PHP)' },
        { key: 'settle', header: 'Days open' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 claim events" />
      <DataTable columns={[
        { key: 'id', header: 'Plan' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Amount (PHP)' },
        { key: 'settle', header: 'Days open' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Claims File Audit Compliance" value={kpiVal('Claims File Audit Compliance')} />
        <KPICard title="Claim File Coverage" value={kpiVal('Claim File Coverage')} />
        <KPICard title="Claim Documents Pending" value={kpiVal('Claim Documents Pending')} />
      </div>
      <Chart data={data?.reconRisk ?? []} type="scatter" xKey="compliance" xName="Claims file audit compliance"
        yKeys={[{ key: 'failed', name: 'Escalated cases' }]} yDomain={[0, 'auto']}
        title="Claims file audit compliance (%) vs escalated cases by plan" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that claims file audits prevented escalations.</p>
      <ActionMemo persona={{ name: 'Maria Teresa Villanueva', role: 'Head of Claims (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft claims actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, plan, claims-reason and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.MICROINSURANCE_AGENT. It uses Cortex Analyst over the semantic view APP.MICROINSURANCE_ANALYTICS for metrics, and Cortex Search over synthetic claims-handling SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the claims agent" mode="advisor" sampleQuestions={['Which 3 plans have the most escalated cases?', 'Which plans are high risk this week and what SOP applies?', 'What is the escalation rate by claim cause?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: 40 synthetic microinsurance plans across 5 Philippine cities, daily plan observations and claim file documents. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION claims escalation risk model evaluated on a time-based holdout, plus a 14-day claims-volume FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags claim document rejection rate outliers per plan over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_CLAIMS, with a Snowflake alert and email on REFERRED claims.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily claims, escalations by plan, escalation risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_CLAIMS inserts simulated claim events into RAW.LIVE_CLAIMS, with a Snowflake alert and email on REFERRED claims. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Controls', icon: '', content: planning },
    { id: 'live', label: 'Live Claims', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Philippine microinsurer. On-demand snapshots are not live claims operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No plan observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Philippines Microinsurance Claims Operations" tabs={tabs} />;
}
