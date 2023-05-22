<template>
  <div class="service">

    <el-card class="box-card panel-container">
      <ServiceListPanel :data="serviceList" :onFetchList="fetchList" :onServiceLog="serviceLog"
        v-loading="isServerListLoading" />
    </el-card>

    <el-card class="box-card panel-container">
      <ServiceControlPanel :onFetchList="fetchList" :onServiceLog="serviceLog" v-loading="isServerListLoading" />
    </el-card>

    <div class="panel-container">
      <el-card class="box-card">
        <el-table :data="consoleLog" height="280" style="width: 100%" class="table" stripe>
          <el-table-column prop="time" label="Time" width="200px" />
          <el-table-column prop="log" label="Log" />
        </el-table>
      </el-card>
    </div>

  </div>
</template>

<script>
import { useMainStorage } from '../stores/main.js'
import ServiceListPanel from '../components/ServiceListPanel.vue'
import ServiceControlPanel from '../components/ServiceControlPanel.vue'

export default {
  name: "ServiceView",
  components: { ServiceListPanel, ServiceControlPanel },
  data: () => {
    return {
      isServerListLoading: false,
      serviceList: [],
      consoleLog: [],
    };
  },
  mounted() {
    this.main = useMainStorage()
    this.fetchList(true, null)
  },
  methods: {
    fetchList(showLoading, completion) {
      if (this.isServerListLoading) { return }
      if (showLoading) {
        this.isServerListLoading = true
      }
      this.main.sendGetRequest("/api/service", (success, error, message, data) => {
        if (error == null) {
          this.serviceList = data.service
        } else {
          this.serviceList = []
        }
        if (completion != null) {
          completion(success, error, message, data)
        }
        this.isServerListLoading = false
      })
    },

    serviceLog(content) {
      if (content == null || content == "") {
        return
      }
      var consoleLog = this.consoleLog
      var logs = content.split('\n').reverse()
      for (var log of logs) {
        if (log == null || log == "") {
          continue
        }
        consoleLog.unshift({
          time: this.main.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss"),
          log: log,
        })
      }
      this.consoleLog = consoleLog
    },
  }
}
</script>
  
<style>
.service {
  height: 100%;
  width: 100%;
  padding-left: 0;
}

.panel-container {
  margin-bottom: 12px;
}

.panel-title {
  padding-left: 12px;
}

.table {
  margin: 12px;
}
</style>
  