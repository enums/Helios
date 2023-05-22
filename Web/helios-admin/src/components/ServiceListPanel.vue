<script setup>
import { VideoPlay, More, CircleCheck, CircleClose, Refresh, Loading } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
</script>

<template>
  <el-table :data="data" style="width: 100%" class="table" stripe>
    <el-table-column type="index" />

    <!-- Name Field -->
    <el-table-column label="Service">
      <template v-slot="scope">
        <span>{{ scope.row.name }}</span>
      </template>
    </el-table-column>

    <!-- Healthy Field -->
    <el-table-column label="Healthy" width="80px" header-align="center" align="center">
      <template v-slot="scope">
        <el-tag class="ml-2" :type="scope.row.isHealthy ? 'success' : 'danger'" @click="checkHealth(scope.row)">
          <el-icon v-if="scope.row.isCheckingHealth" class="is-loading">
            <Loading />
          </el-icon>
          <el-icon v-if="!scope.row.isCheckingHealth">
            <CircleCheck v-if="scope.row.isHealthy"></CircleCheck>
            <CircleClose v-else></CircleClose>
          </el-icon>
        </el-tag>
      </template>
    </el-table-column>

    <!-- Status Field -->
    <el-table-column label="Status" width="120px" header-align="center" align="center">
      <template v-slot="scope">
        <el-tag class="status" :type="scope.row.isRunning ? 'success' : 'danger'" effect="dark">
          {{ scope.row.isRunning ? 'Running' : 'Stopped' }}
        </el-tag>
      </template>
    </el-table-column>
    <el-table-column label="Start Date" width="200px">
      <template v-slot="scope">
        <span>{{ scope.row.startDate }}</span>
      </template>
    </el-table-column>

    <!-- Operation Field -->
    <el-table-column label="Operation" width="160px">
      <template v-slot="scope">
        <!-- Confirmation Popover -->
        <el-popover placement="left" trigger="focus" :width="180">
          <p>Operation conformation</p>
          <div style="text-align: right; margin-top: 8px;">
            <el-button size="small" :type="scope.row.isRunning ? 'danger' : 'success'" :loading="scope.row.isLoading"
              round @click="scope.row.isRunning ? killService(scope.row) : runService(scope.row)" style="width: 100%">
              Confirm to {{ scope.row.isRunning ? 'Stop' : 'Run' }}
            </el-button>
          </div>
          <template #reference>
            <el-button class="action" :loading="scope.row.isLoading" :type="scope.row.isRunning ? 'danger' : 'success'"
              size="small" :icon="scope.row.isRunning ? CircleClose : VideoPlay" round>
              {{ scope.row.isRunning ? 'Stop' : 'Run' }}
            </el-button>
          </template>
        </el-popover>
        <!-- Operation Override -->
        <el-popover placement="left" trigger="focus" :width="280">
          <template #reference>
            <el-button :icon="More" size="small" circle @click.stop />
          </template>
          <p align="center">Operation override</p>
          <el-row style="margin-top: 8px;">
            <el-col :span="8" align="center">
              <el-button class="action" :icon="VideoPlay" :loading="scope.row.isLoading" size="small" type="success"
                round @click="runService(scope.row)">Run</el-button>
            </el-col>
            <el-col :span="8" align="center">
              <el-button class="action" :icon="Refresh" :loading="scope.row.isLoading" size="small" type="warning" round
                @click="rebootService(scope.row)">Reboot</el-button>
            </el-col>
            <el-col :span="8" align="center">
              <el-button class="action" :icon="CircleClose" :loading="scope.row.isLoading" size="small" type="danger"
                round @click="killService(scope.row)">Stop</el-button>
            </el-col>
          </el-row>
        </el-popover>
      </template>
    </el-table-column>
  </el-table>
</template>

<script>
import { useMainStorage } from '../stores/main.js'
export default {
  name: 'ServiceListPanel',
  props: {
    onFetchList: Function,
    onServiceLog: Function,
    data: Object,
  },
  data: () => {
    return {
      isLoading: false,
    }
  },
  mounted() {
    this.main = useMainStorage()
  },
  beforeUnmount() {
  },
  watch: {
    data: function (newValue, oldValue) {
      console.log('data changed')
      this.checkAllHealth()
    }
  },
  methods: {

    runService(service) {
      if (service.isLoading) { return }
      service.isLoading = true
      this.onServiceLog('Booting service `' + service.name + '`...')
      this.main.sendActionRequest("/api/service", "run", "name=" + service.name, null, (success, error, message, data) => {
        this.onServiceLog(message)
        if (error == null) {
          ElMessage({
            message: 'Boot service `' + service.name + '` succeed!',
            type: 'success',
          })
          this.onFetchList(false, (success, error, message, data) => {
            service.isLoading = false
            this.checkAllHealth()
          })
        } else {
          alert(error)
          service.isLoading = false
          ElMessage.error({
            message: 'Boot service `' + service.name + '` failed! Error: ' + message
          })
        }
      })
    },

    killService(service) {
      if (service.isLoading) { return }
      service.isLoading = true
      this.onServiceLog('Killing service `' + service.name + '`...')
      this.main.sendActionRequest("/api/service", "kill", "name=" + service.name, null, (success, error, message, data) => {
        if (error == null) {
          this.onServiceLog(message)
          ElMessage({
            message: 'Kill service `' + service.name + '` succeed!',
            type: 'success',
          })
          this.onFetchList(false, (success, error, message, data) => {
            service.isLoading = false
            this.checkAllHealth()
          })
        } else {
          service.isLoading = false
          ElMessage.error({
            message: 'Kill service `' + service.name + '` failed! Error: ' + message
          })
        }
      })
    },

    rebootService(service) {
      if (service.isLoading) { return }
      service.isLoading = true
      this.onServiceLog('Rebooting service `' + service.name + '`...')
      this.main.sendActionRequest("/api/service", "reboot", "name=" + service.name, null, (success, error, message, data) => {
        this.onServiceLog(message)
        if (error == null) {
          ElMessage({
            message: 'Reboot service `' + service.name + '` succeed!',
            type: 'success',
          })
          this.onFetchList(false, (success, error, message, data) => {
            service.isLoading = false
            this.checkAllHealth()
          })
        } else {
          service.isLoading = false
          ElMessage.error({
            message: 'Reboot service `' + service.name + '` failed! Error: ' + message
          })
        }
      })
    },

    checkAllHealth() {
      this.data.forEach(service => {
        if (service.isRunning) {
          this.checkHealth(service)
        }
      })
    },

    checkHealth(service) {
      if (service.isCheckingHealth) { return }
      this.onServiceLog('Checking service `' + service.name + '`...')
      service.isCheckingHealth = true
      this.main.sendActionRequest("/api/service", "healthCheck", "name=" + service.name, null, (success, error, message, data) => {
        this.onServiceLog(message)
        if (error == null) {
          service.isHealthy = success
          service.isCheckingHealth = false
        } else {
          service.isCheckingHealth = false
        }
      })
    }
  },
}
</script>

<style>
.table {
  margin: 12px;
}

.action {
  width: 72px
}

.status {
  width: 66px
}
</style>