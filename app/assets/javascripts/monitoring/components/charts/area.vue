<script>
import { GlAreaChart } from '@gitlab/ui/dist/charts';
import dateFormat from 'dateformat';
import { debounceByAnimationFrame } from '~/lib/utils/common_utils';
import { getSvgIconPathContent } from '~/lib/utils/icon_utils';
import Icon from '~/vue_shared/components/icon.vue';

let debouncedResize;

export default {
  components: {
    GlAreaChart,
    Icon,
  },
  inheritAttrs: false,
  props: {
    graphData: {
      type: Object,
      required: true,
      validator(data) {
        return (
          data.queries &&
          Array.isArray(data.queries) &&
          data.queries.filter(query => {
            if (Array.isArray(query.result)) {
              return (
                query.result.filter(res => Array.isArray(res.values)).length === query.result.length
              );
            }
            return false;
          }).length === data.queries.length
        );
      },
    },
    containerWidth: {
      type: Number,
      required: true,
    },
    deploymentData: {
      type: Array,
      required: false,
      default: () => [],
    },
    alertData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      tooltip: {
        title: '',
        content: '',
        isDeployment: false,
        sha: '',
      },
      width: 0,
      height: 0,
      scatterSymbol: undefined,
    };
  },
  computed: {
    chartData() {
      return this.graphData.queries.reduce((accumulator, query) => {
        accumulator[query.unit] = query.result.reduce((acc, res) => acc.concat(res.values), []);
        return accumulator;
      }, {});
    },
    chartOptions() {
      return {
        xAxis: {
          name: 'Time',
          type: 'time',
          axisLabel: {
            formatter: date => dateFormat(date, 'h:MM TT'),
          },
          axisPointer: {
            snap: true,
          },
          nameTextStyle: {
            padding: [18, 0, 0, 0],
          },
        },
        yAxis: {
          name: this.yAxisLabel,
          axisLabel: {
            formatter: value => value.toFixed(3),
          },
          nameTextStyle: {
            padding: [0, 0, 36, 0],
          },
        },
        legend: {
          formatter: this.xAxisLabel,
        },
        series: this.scatterSeries,
      };
    },
    earliestDatapoint() {
      return Object.values(this.chartData).reduce((acc, data) => {
        const [[timestamp]] = data.sort(([a], [b]) => {
          if (a < b) {
            return -1;
          }
          return a > b ? 1 : 0;
        });

        return timestamp < acc || acc === null ? timestamp : acc;
      }, null);
    },
    recentDeployments() {
      return this.deploymentData.reduce((acc, deployment) => {
        if (deployment.created_at >= this.earliestDatapoint) {
          acc.push({
            id: deployment.id,
            createdAt: deployment.created_at,
            sha: deployment.sha,
            commitUrl: `${this.projectPath}/commit/${deployment.sha}`,
            tag: deployment.tag,
            tagUrl: deployment.tag ? `${this.tagsPath}/${deployment.ref.name}` : null,
            ref: deployment.ref.name,
            showDeploymentFlag: false,
          });
        }

        return acc;
      }, []);
    },
    scatterSeries() {
      return {
        type: 'scatter',
        data: this.recentDeployments.map(deployment => [deployment.createdAt, 0]),
        symbol: this.scatterSymbol,
        symbolSize: 14,
      };
    },
    xAxisLabel() {
      return this.graphData.queries.map(query => query.label).join(', ');
    },
    yAxisLabel() {
      const [query] = this.graphData.queries;
      return `${this.graphData.y_label} (${query.unit})`;
    },
  },
  watch: {
    containerWidth: 'onResize',
  },
  beforeDestroy() {
    window.removeEventListener('resize', debouncedResize);
  },
  created() {
    debouncedResize = debounceByAnimationFrame(this.onResize);
    window.addEventListener('resize', debouncedResize);
    this.getScatterSymbol();
  },
  methods: {
    formatTooltipText(params) {
      const [seriesData] = params.seriesData;
      this.tooltip.isDeployment = seriesData.componentSubType === 'scatter';
      this.tooltip.title = dateFormat(params.value, 'dd mmm yyyy, h:MMTT');
      if (this.tooltip.isDeployment) {
        const [deploy] = this.recentDeployments.filter(
          deployment => deployment.createdAt === seriesData.value[0],
        );
        this.tooltip.sha = deploy.sha.substring(0, 8);
      } else {
        this.tooltip.content = `${this.yAxisLabel} ${seriesData.value[1].toFixed(3)}`;
      }
    },
    getScatterSymbol() {
      getSvgIconPathContent('rocket')
        .then(path => {
          if (path) {
            this.scatterSymbol = `path://${path}`;
          }
        })
        .catch(() => {});
    },
    onResize() {
      const { width, height } = this.$refs.areaChart.$el.getBoundingClientRect();
      this.width = width;
      this.height = height;
    },
  },
};
</script>

<template>
  <div class="prometheus-graph col-12 col-lg-6">
    <div class="prometheus-graph-header">
      <h5 ref="graphTitle" class="prometheus-graph-title">{{ graphData.title }}</h5>
      <div ref="graphWidgets" class="prometheus-graph-widgets"><slot></slot></div>
    </div>
    <gl-area-chart
      ref="areaChart"
      v-bind="$attrs"
      :data="chartData"
      :option="chartOptions"
      :format-tooltip-text="formatTooltipText"
      :thresholds="alertData"
      :width="width"
      :height="height"
    >
      <template slot="tooltipTitle">
        <div v-if="tooltip.isDeployment">
          {{ __('Deployed') }}
        </div>
        {{ tooltip.title }}
      </template>
      <template slot="tooltipContent">
        <div v-if="tooltip.isDeployment" class="d-flex align-items-center">
          <icon name="commit" class="mr-2" />
          {{ tooltip.sha }}
        </div>
        <template v-else>
          {{ tooltip.content }}
        </template>
      </template>
    </gl-area-chart>
  </div>
</template>
