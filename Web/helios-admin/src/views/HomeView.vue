<script setup>
import { useMainStorage } from '../stores/main.js'
</script>

<template>
  <div class="home">
    <!-- <el-button type="primary" @click="buttonTapped">Primary</el-button> -->
    <el-row :gutter="20">

      <!-- Services -->
      <el-col :span="8">
        <el-card class="box-card card-panel" v-loading="isLoading">
          <el-row>
            <p>Service Status</p>
          </el-row>
          <div style="height: 12px"></div>
          <el-row>
            <el-col :span="24" align="center">
              <el-progress type="dashboard" :percentage="serviceRunningPercent">
                <template #default="{ percentage }">
                  <span class="percentage-value">{{ percentage }}%</span>
                  <span class="percentage-label">{{ hasServiceData ? data.Service.runningService : 0 }} / {{
                  hasServiceData ? data.Service.totalService : 0 }}</span>
                </template>
              </el-progress>
              <p>Services</p>
            </el-col>
          </el-row>
        </el-card>
      </el-col>

      <!-- Logger -->
      <el-col :span="16">
        <el-card class="box-card card-panel" v-loading="isLoading">
          <p class="mx-1 panel-title">Logger Cache</p>
          <div style="height: 12px"></div>
          <el-row>
            <el-col :span="12" align="center">
              <el-progress type="dashboard" :percentage="loggerTrackUsagePercent">
                <template #default="{ percentage }">
                  <span class="percentage-value">{{ percentage }}%</span>
                  <span class="percentage-label">{{ hasLoggerData ? data.Logger.track.cacheUsed : 0 }} / {{
                  hasLoggerData ? data.Logger.track.cacheSize : 0 }}</span>
                </template>
              </el-progress>
              <p>Track Cache</p>
            </el-col>
            <el-col :span="12" align="center">
              <el-progress type="dashboard" :percentage="loggerEventUsagePercent">
                <template #default="{ percentage }">
                  <span class="percentage-value">{{ percentage }}%</span>
                  <span class="percentage-label">{{ hasLoggerData ? data.Logger.event.cacheUsed : 0 }} / {{
                  hasLoggerData ? data.Logger.event.cacheSize : 0 }}</span>
                </template>
              </el-progress>
              <p>Event Cache</p>
            </el-col>
          </el-row>
        </el-card>
      </el-col>

    </el-row>
  </div>
</template>

<script>
import { useMainStorage } from '../stores/main.js'

export default {
  name: "HomeView",
  components: {},
  data: () => {
    return {
      isLoading: false,
      data: {
        Service: {
          runningService: 0,
          totalService: 0,
        },
        Logger: {
          track: {
            cacheUsed: 0,
            cacheSize: 0,
          },
          event: {
            cacheUsed: 0,
            cacheSize: 0,
          },
        }
      },
    }
  },
  mounted() {
    this.main = useMainStorage()
    this.fetchOverall()
  },
  computed: {

    hasServiceData() {
      return this.data.Service != null
    },

    hasLoggerData() {
      return this.data.Logger != null
    },

    serviceRunningPercent() {
      if (!this.hasServiceData || this.data.Service.totalService <= 0) {
        return 0
      } else {
        return Number((this.data.Service.runningService * 100 / this.data.Service.totalService).toFixed(0))
      }
    },

    loggerTrackUsagePercent() {
      if (!this.hasLoggerData || this.data.Logger.track.cacheSize <= 0) {
        return 0
      } else {
        return Number((this.data.Logger.track.cacheUsed * 100 / this.data.Logger.track.cacheSize).toFixed(2))
      }
    },

    loggerEventUsagePercent() {
      if (!this.hasLoggerData || this.data.Logger.event.cacheSize <= 0) {
        return 0
      } else {
        return Number((this.data.Logger.event.cacheUsed * 100 / this.data.Logger.event.cacheSize).toFixed(2))
      }
    }
  },
  methods: {
    fetchOverall() {
      if (this.isLoading) { return }
      this.main.sendGetRequest("/api/overall", (success, error, message, data) => {
        if (error == null) {
          this.data = data
        } else {
          this.data = {}
        }
        this.isLoading = false
      })
    },
  }
}
</script>

<style>
.home {
  height: 100%;
  width: 100%;
  padding-left: 0;
}

.percentage-value {
  display: block;
  margin-top: 10px;
  font-size: 28px;
}

.percentage-label {
  display: block;
  margin-top: 10px;
  font-size: 12px;
}

.card-panel {
  height: 240px;
}
</style>
