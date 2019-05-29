rem by vodkabears
rem https://github.com/vodka-bears/ersky9x-betaflight-vtx-script
rem derivative of this
rem https://github.com/midelic/Ersky9x-Tx-bas-scripts/blob/master/src/BF_basic.bas

rem A script to control a vtx with ersky9x with betaflight (if it works with iNav I say wow)
rem put in /scripts
rem works with SmartPort and FPort

if init = 0
	init = 1
	
	rem if you want a debug screen set this to 1
	DEBUG_MODE = 1
	
	SPORT_REMOTE_SENSOR_ID = 0x1B
	FPORT_REMOTE_SENSOR_ID = 0x00
	
	SPORT_MSP_VERSION = 32
	SPORT_MSP_STARTFLAG = 16
	LOCAL_SENSOR_ID = 0x0D
	REQUEST_FRAME_ID = 0x30
	REPLY_FRAME_ID  = 0x32
	MSP_RC_TUNING     = 111
	MSP_SET_PID       = 202
	MSP_PID           = 112
	MSP_SET_RC_TUNING = 204
	MSP_PID_ADVANCED     = 94
	MSP_SET_PID_ADVANCED = 95
	MSP_VTX_CONFIG = 88
	MSP_SET_VTX_CONFIG = 89
	MSP_REBOOT = 68
	MSP_EEPROM_WRITE = 250
	REQ_TIMEOUT = 80

	PAGE_DISPLAY	= 2
	EDITING			= 3
	PAGE_SAVING		= 4
	MENU_DISP		= 5
	TEST			= 6
	
	currentPage = 1
	currentLine = 1
	saveTS = 0
	saveRetries = 0	
	gState = PAGE_DISPLAY

	sportMspSeq = 0
	sportMspRemoteSeq = 0
	sportMspRemoteSeqm = 0
	rem --- Rx values
	array byte mspRxBuf[32]
	mspRxIdx = 1
	mspRxCRC = 0
	mspStarted = false
	mspLastReq = 0
	
	rem --- TX values
	array byte mspTxBuf[34]
	mspTxIdx = 1
	mspTxCRC = 0
	mspTxPk = 0

	mspRequestsSent = 0
	mspRepliesReceived = 0
	mspPkRxed = 0
	mspErrorPk = 0
	mspStartPk = 0
	mspOutOfOrder = 0
	mspCRCErrors = 0
	
	array byte payload[7]
	array byte payloadTx[7]
	array byte payloadReq[32]
	array byte values_pid[32]
	array byte values_rates[32]
	array byte values_vtx_recieved[32]
	array      values_vtx[32]
	array byte values_vtx_send[32]
	
	array freqA[9]
	array freqB[9]
	array freqE[9]
	array freqF[9]
	array freqR[9]
	
	freqA[1] = 5865
	freqA[2] = 5845
	freqA[3] = 5825
	freqA[4] = 5805
	freqA[5] = 5785
	freqA[6] = 5765
	freqA[7] = 5745
	freqA[8] = 5725
	
	freqB[1] = 5733
	freqB[2] = 5752
	freqB[3] = 5771
	freqB[4] = 5790
	freqB[5] = 5809
	freqB[6] = 5828
	freqB[7] = 5847
	freqB[8] = 5866
	
	freqE[1] = 5705
	freqE[2] = 5685
	freqE[3] = 5665
	freqE[4] = 5645
	freqE[5] = 5885
	freqE[6] = 5905
	freqE[7] = 5925
	freqE[8] = 5945
	
	freqF[1] = 5740
	freqF[2] = 5760
	freqF[3] = 5780
	freqF[4] = 5800
	freqF[5] = 5820
	freqF[6] = 5840
	freqF[7] = 5860
	freqF[8] = 5880
	
	freqR[1] = 5658
	freqR[2] = 5695
	freqR[3] = 5732
	freqR[4] = 5769
	freqR[5] = 5806
	freqR[6] = 5843
	freqR[7] = 5880
	freqR[8] = 5917
	
	val = 0
	lastReqTS = 0	
	result = 0
	startm = 0
	headm = 0
	err_flag = 0
	now = 0
	seq = 0
	ret = 0
end

goto run

mspSendRequest:
	rem -- busy
	if t_size != 0
		return
	end

	mspTxBuf[1] = p_size
	mspTxBuf[2] = cmnd & 0xFF

	if p_size > 1
		j = 1
		while  j <= p_size
			mspTxBuf[j+2] = payloadReq[j]
			j += 1
		end
	end

	mspLastReq = cmnd
	mspRequestsSent += 1
	t_size = p_size + 2
	gosub mspProcessTxQ
return

mspProcessTxQ:
	if t_size = 0
		return
	end
	rem ---check if the previous frame is sent before send the next
	rest = sportTelemetrySend(0xFF)
	if rest = 0 
		return 
	end

	j = 1
	while j <= 6
		payloadTx[j] = 0
		j += 1
	end

	mspRequestsSent += 1

	payloadTx[1] = sportMspSeq + SPORT_MSP_VERSION
	sportMspSeq += 1
	sportMspSeq = sportMspSeq & 0x0F
	
	
	if mspTxIdx = 1 
		rem --- start flag only for id=1
		payloadTx[1] +=SPORT_MSP_STARTFLAG
	end

	i = 2
	while i <= 6
		rem --- payloadTx[2]=payload size
		payloadTx[i] = mspTxBuf[mspTxIdx]
		mspTxIdx = mspTxIdx + 1
		mspTxCRC ^= payloadTx[i]
		i += 1
		if mspTxIdx > t_size
			break
		end
	end

	if i <= 6 
		payloadTx[i] = mspTxCRC  
		i = i + 1
		rem --- zero fill
		while i <= 6 
			payloadTx[i] = 0
			i += 1
		end 	
		gosub mspSendSport

		rem ---reset buffer
		j = 1
		while j < 32
			mspTxBuf[j] = 0
			j += 1
		end
		t_size = 0
		mspTxIdx = 1
		mspTxCRC = 0
		return
	end
 
	gosub mspSendSport
return

mspSendSport:
	dataId = 0
	dataId=payloadTx[1] + payloadTx[2] * 256
	value = 0
	value = payloadTx[3] + payloadTx[4] * 256 + payloadTx[5] * 65536 + 	payloadTx[6] * 16777216
	reti = sportTelemetrySend(LOCAL_SENSOR_ID, REQUEST_FRAME_ID, dataId, value)
	if reti > 0 	
		mspTxPk += 1
	end
return

mspReceivedReply:
	mspPkRxed += 1  
	idx = 1
	head = payload[idx]
	
	headm = head & 0x20
	
	if headm # 0 
		err_flag = 1
	else
		err_flag = 0
	end
	
	idx += 1

	if err_flag = 1
		mspStarted = 0
		mspErrorPk += 1
		ret = 0
		return
	end

	startm = head & 0x10
	
	if startm # 0
		start = 1
	else
		start = 0
	end
	
	seq = head & 0x0F
		
	if start	
		j = 1
		while j	< 32
			mspRxBuf[j]=0
			j += 1
		end
	
		sportMspRemoteSeqm = sportMspRemoteseq + 1
		sportMspRemoteSeqm &= 0x0F    
		mspRxIdx = 1
		mspRxSize = payload[idx]
		mspRxCRC = mspRxSize ^ mspLastReq
		idx += 1
		mspStarted = true      
		mspStartPk += 1		
	elseif mspStarted = false	
		mspOutOfOrder += 1
		ret = 0		
		rem return
	elseif sportMspRemoteseqm # seq
		rem mspStarted = false
		ret = 0
		rem return
	end
	
	
	while (idx <= 6) & (mspRxIdx <= mspRxSize)
		mspRxBuf[mspRxIdx] = payload[idx]
		mspRxCRC ^= payload[idx]
		mspRxIdx += 1		
		idx += 1
	end
	
	
	if idx > 6
		sportMspRemoteSeq = seq
		ret = 1
		return	
	end

	if mspRxCRC # payload[idx]
		mspStarted = 0
		mspCRCErrors += 1
		ret = 0
		return
	end
	
	mspRepliesReceived += 1
	mspStarted = 0
	ret = 2
	rem --return mspRxBuf
return

mspPollReply:
	while 1
		result = sportTelemetryReceive( physicalId, primId, dataId , value)
		if result > 0
			if ((physicalId = SPORT_REMOTE_SENSOR_ID) | (physicalId = FPORT_REMOTE_SENSOR_ID)) & (primId = 0x32)
				j=1
				while j<=6
					payload[j]=0
					j += 1
				end
				payload[1] = dataId & 0xFF
				dataId /= 256
				payload[2] = dataId & 0xFF
				payload[3] = value & 0xFF
				value /= 256
				value = value & 0xFFFFFF
				payload[4] = value & 0xFF
				value /= 256
				payload[5] = value & 0xFF
				value /= 256
				payload[6] = value & 0xFF
				gosub mspReceivedReply
				if ret = 2
					cmd = mspLastReq
					return
				end
			else
				cmd = 0
				return
 			end
		else
			cmd = 0
			return
		end
	end
return

processMspReply:
	if cmd = 0
		return
	end

	page = currentPage
	gosub SetupPages

	rem ---ignore write for now

	if cmd = write
		cmnd = MSP_EEPROM_WRITE
		p_size = 0
		gosub payload_zero
		gosub mspSendRequest
		return
	end

	if cmd = MSP_EEPROM_WRITE
		gState = PAGE_DISPLAY
		gosub empty_buffer
		saveTS = 0
	end

	if cmd != read
		return
	end 

	if ret = 2
		if mspRxIdx > 1
			j = 1
			while j <= mspRxIdx
				if page = 1
					values_pid[j] = mspRxBuf[j]
				elseif page = 2
					values_rates[j] = mspRxBuf[j]
				elseif page = 3
					values_vtx_recieved[j] = mspRxBuf[j]
				end
				j += 1
			end
			if page = 3
				gosub convertRecievedVtxValues
			end
		end
		ret = 0
	end
return

convertRecievedVtxValues:
	rem //Type
	values_vtx[5] = values_vtx_recieved[1]
	rem //Band
	values_vtx[1] = values_vtx_recieved[2]
	rem //Channel
	values_vtx[2] = values_vtx_recieved[3]
	rem //Power
	values_vtx[3] = values_vtx_recieved[4]
	rem //Pitmode
	values_vtx[4] = values_vtx_recieved[5]
	rem //Freq
	values_vtx[6] = values_vtx_recieved[6] + values_vtx_recieved[7]*256
	rem //Ready
	values_vtx[7] = values_vtx_recieved[8]
return

convertVtxValuesSend:
	if values_vtx[1] = 0
		channel = values_vtx[6]
	else
		channel = (values_vtx[1] - 1)*8 + values_vtx[2] - 1
	end
	
	values_vtx_send[1] = channel & 0xFF
	values_vtx_send[2] = (channel / 256) & 0xFF
	values_vtx_send[3] = values_vtx[3] & 0xFF
	values_vtx_send[4] = values_vtx[4] & 0xFF
return

setFreqFromBandChan:
	chanNum = values_vtx[2]
	if values_vtx[1] = 1
		values_vtx[6] = freqA[chanNum]
	elseif values_vtx[1] = 2
		values_vtx[6] = freqB[chanNum]
	elseif values_vtx[1] = 3
		values_vtx[6] = freqE[chanNum]
	elseif values_vtx[1] = 4
		values_vtx[6] = freqF[chanNum]
	elseif values_vtx[1] = 5
		values_vtx[6] = freqR[chanNum]
	end
return

empty_buffer:
	j = 1
	while j <= packet_size
		if page = 1
			values_pid[j] = 0
		elseif page = 2
			values_rates[j] = 0
		elseif page = 3
			values_vtx_recieved[j] = 0
		end
		j += 1
 	end
return

payload_zero:
	j = 1
	while j < 32
		payloadReq[j] = 0
		j += 1
	end
return

requestPage:
	if reqTS = 0
		reqTS = gettime()
		gosub payload_zero
		p_size = 0
		cmnd = read
		gosub mspSendRequest
	elseif reqTS + REQ_TIMEOUT <= gettime()
		reqTS = gettime()
		gosub payload_zero
		p_size = 0
		cmnd = read
		gosub mspSendRequest
	end
return

incLine:
	currentLine += 1
	if currentLine > MaxLines 
		currentLine = 1
	elseif currentLine < 1 
		currentLine = MaxLines
	end
return

decLine:
	currentLine -= 1
	if currentLine > MaxLines 
		currentLine = 1
	elseif currentLine < 1 
		currentLine = MaxLines
	end
return

incPage:
	currentPage += 1
	if currentPage > 3 
		currentPage = 1
	elseif currentPage < 1 
		currentPage = 3
	end
	currentLine = 1
return

incValue:
	page = currentPage
	z = currentLine
	if page = 1
		val = values_pid[z]
	elseif page = 2 
		val = values_rates[z]
	elseif page = 3
		if (z = 5) | (z = 7)
			return
		end
		if z = 6
			if values_vtx[5] # 1
				return
			else
				values_vtx[1] = 0
				values_vtx[2] = 0
			end
		end
		values_vtx[z] += 1
		val = values_vtx[z]
		gosub clipValueVtx
		values_vtx[z] = val
		if z < 3
			gosub setFreqFromBandChan
		end
		return
	end
	val += 1
	gosub clipValue
	if page = 1
		values_pid[z] = val
	elseif page = 2
		values_rates[z] = val
	end
return

decValue:
	page = currentPage
	z = currentLine
	if page = 1
		val = values_pid[z]
	elseif page = 2 
		val = values_rates[z]
	elseif page = 3
		if (z = 5) | (z = 7)
			return
		end
		if z = 6
			if values_vtx[5] # 1
				return
			else
				values_vtx[1] = 0
				values_vtx[2] = 0
			end
		end
		values_vtx[z] -= 1
		val = values_vtx[z]
		gosub clipValueVtx
		values_vtx[z] = val
		if z < 3
			gosub setFreqFromBandChan
		end
		return
	end
	val -= 1
	gosub clipValue
	if page = 1
		values_pid[z] = val
	elseif page = 2
		values_rates[z] = val
	end
return

clipValue:
	if val < 0 
		val = 0
	elseif val > 255 
		val = 255
	end
return

clipValueVtx:
	if z = 1
		if val < 1
			val = 1
		elseif val > 5
			val = 5
		end
	elseif z = 2
		if val < 1
			val = 1
		elseif val > 8
			val = 8
		end
	elseif z = 3
		if values_vtx[5] = 1
			if val < 0
				val = 0
			elseif val > 2
				val = 2
			end
		elseif values_vtx[5] = 3
			if val < 1
				val = 1
			elseif val > 4
				val = 4
			end
		elseif values_vtx[5] = 4
			if val < 0
				val = 0
			elseif val > 5
				val = 5
			end
		end
	elseif z = 4
		if values_vtx[5] < 3
			val = 0
		else
			if val < 0
				val = 1
			elseif val > 1
				val = 0
			end
		end
	elseif z = 6
		if val < 5600
			val = 5600
		elseif val < 5950
			val = 5950
		end
	end
return

SetupPages:
	if page = 1
		rem --- 0x1E size
		packet_size = 30
		MaxLines = 8
		read = MSP_PID
		write = MSP_SET_PID
	elseif page = 2
		rem ---0x0C size
		packet_size = 12
		MaxLines = 7
		read = MSP_RC_TUNING
		write = MSP_SET_RC_TUNING
	elseif page = 3
		rem --- WTF is size?
		packet_size = 9
		MaxLines = 7
		read = MSP_VTX_CONFIG
		write = MSP_SET_VTX_CONFIG
	end
return


selectone:
	text_options = 0
	if j = currentLine
		text_options = INVERS
		if gState = EDITING 
			text_options = text_options + BLINK
		end
	end
return

check_values:
	j = 1
	c = 1
	v_flag = 0
	while j <= packet_size
		if page = 1
			if values_pid[j] = 0
				c += 1
			end
		elseif page = 2
			if values_rates[j] = 0
				c += 1
			end
		elseif page = 3
			if values_vtx[j] = 0
				c += 1
			end
		end
		j += 1
	end
	rem --if all values are zero
	if c  >=  packet_size
		v_flag = 0
	else
		v_flag = 1
	end
return

saveSettings:
	rem --write commands

	gosub check_values	
	if page = 3
		gosub convertVtxValuesSend
	end
	if v_flag
		cmnd = write
		p_size = packet_size
		j = 1
		while j <= packet_size
			if page = 1
				payloadReq[j] = values_pid[j]
			elseif page = 2
				payloadReq[j] = values_rates[j]
			elseif page = 3
				payloadReq[j] = values_vtx_send[j]
			end	  
			j = j+1
		end
		gosub mspSendRequest
		saveTS = gettime()
		if gState = PAGE_SAVING 
			saveRetries = saveRetries + 1
		else
			gState = PAGE_SAVING
		end
	end
return

invalidatePages:
	j = 1
	while j < 32
		values_pid[j] = 0
		values_rates[j] = 0
		values_vtx[j] = 0
		j += 1
	end
	gState = PAGE_DISPLAY
	saveTS = 0
return

rebootFC:
	cmnd = MSP_REBOOT
	p_size = 0
	gosub payload_zero
	gosub mspSendRequest
return

drawTestScreen:
	rem ---here you can add any variable that you want to be displayed on the screen 
	rem ---for debugging purposes
	drawtext( 0, 0, "Nothing here", INVERS+BLINK)
	
return

drawScreen:
	if page = 1
		drawtext( 0, 0, "PIDs", INVERS )
		drawtext( 111, 0, "1/3", 0 )

		drawtext( 4, 25, "Roll", 0 )
		drawtext( 4, 36, "Pitch", 0 )
		drawtext( 4, 47, "Yaw", 0 )	 
 
		drawtext( 50, 14, "P", 0 )
		drawtext( 78, 14, "I", 0 )
		drawtext( 106, 14, "D", 0 )

		j = 1
		gosub selectone
		drawnumber( 55, 25, values_pid[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 83, 25, values_pid[j], text_options)
		j += 1
		gosub selectone
		drawnumber( 111, 25, values_pid[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 55, 36, values_pid[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 83, 36, values_pid[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 111, 36, values_pid[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 55, 47, values_pid[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 83, 47, values_pid[j], text_options )

		rem j += 1
		rem gosub selectone
		rem drawnumber( 111, 47, values_pid[j],text_options )

	elseif page = 2 
		drawtext( 0, 0, "Rates", INVERS )
		drawtext( 111, 0, "2/3", 0 )

		drawtext( 4, 25, "Roll", 0 )
		drawtext( 4, 36, "Pitch", 0 )
		drawtext( 4, 47, "Yaw", 0 )

		drawtext( 39, 9, "RC", 0 )
		drawtext( 39, 16, "Rate", 0 )

		drawtext( 69, 9, "Super", 0 )
		drawtext( 69, 16, "Rate", 0 )

		drawtext( 97, 9, "RC", 0 )
		drawtext( 97, 16, "Expo", 0 )

		j = 1
		gosub selectone
		drawnumber( 55, 30, values_rates[j], text_options)
		j += 1
		gosub selectone
		drawnumber( 111, 30, values_rates[j], text_options)
		j += 1
		gosub selectone
		drawnumber( 83, 25, values_rates[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 83, 36, values_rates[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 83, 47,values_rates[j], text_options )
		j += 1
		gosub selectone
		drawnumber( 55, 47, values_rates[j+6], text_options)
		j += 1
		gosub selectone
		drawnumber( 111, 47, values_rates[j+6], text_options)
	elseif page = 3
		drawtext( 0, 0, "VTX", INVERS )
		drawtext( 111, 0, "3/3", 0 )		
		drawtext(4, 14, "Band:", 0)
		drawtext(4, 24, "Ch:", 0)
		drawtext(4, 34, "Pw:", 0)
		if values_vtx[5] = 1
			drawtext(4, 44, "Pit.", 0)
		else
			drawtext(4, 44, "Pit:", 0)
		end
		
		drawtext(64, 14, "Dev.", 0)
		if values_vtx[5] = 1
			drawtext(64, 24, "Freq:", 0)
		else
			drawtext(64, 24, "Freq.", 0)
		end
		drawtext(64, 34, "Rdy.", 0)
		
		j = 1
		gosub selectone
		if values_vtx[j] = 0
			drawtext(40, 14, "0", text_options)
		elseif values_vtx[j] = 1
			drawtext(40, 14, "A", text_options)
		elseif values_vtx[j] = 2
			drawtext(40, 14, "B", text_options)
		elseif values_vtx[j] = 3
			drawtext(40, 14, "E", text_options)
		elseif values_vtx[j] = 4
			drawtext(40, 14, "F", text_options)
		elseif values_vtx[j] = 5
			drawtext(40, 14, "R", text_options)
		else
			drawtext(40, 14, "OOR", text_options)
		end
		
		j = 2
		gosub selectone
		if (values_vtx[j] > 8) | (values_vtx[j] < 0)
			drawtext(40, 24, "OOR", text_options)
		else
			drawnumber(40, 24, values_vtx[j], text_options + LEFT)
		end
		
		j = 3
		gosub selectone
		if values_vtx[5] = 1
			if values_vtx[j] = 0
				drawtext(40, 34, "OFF", text_options)
			elseif values_vtx[j] = 1
				drawtext(40, 34, "25", text_options)
			elseif values_vtx[j] = 2
				drawtext(40, 34, "200", text_options)
			else
				drawtext(40, 34, "OOR", text_options)
			end
		elseif values_vtx[5] = 2
				drawtext(40, 34, "WTF", text_options)
		elseif values_vtx[5] = 3
			if values_vtx[j] = 0
				drawtext(40, 34, "OFF", text_options)
			elseif values_vtx[j] = 1
				drawtext(40, 34, "25", text_options)
			elseif values_vtx[j] = 2
				drawtext(40, 34, "200", text_options)
			elseif values_vtx[j] = 3
				drawtext(40, 34, "500", text_options)
			elseif values_vtx[j] = 3
				drawtext(40, 34, "500", text_options)
			elseif values_vtx[j] = 4
				drawtext(40, 34, "800", text_options)
			end
		elseif values_vtx[5] = 4
			if values_vtx[j] = 0
				drawtext(40, 34, "OFF", text_options)
			elseif values_vtx[j] = 1
				drawtext(40, 34, "25", text_options)
			elseif values_vtx[j] = 2
				drawtext(40, 34, "100", text_options)
			elseif values_vtx[j] = 3
				drawtext(40, 34, "200", text_options)
			elseif values_vtx[j] = 4
				drawtext(40, 34, "400", text_options)
			elseif values_vtx[j] = 5
				drawtext(40, 34, "600", text_options)
			end
		end
		
		j = 4
		gosub selectone
		if values_vtx[j] = 0
			drawtext(40, 44, "OFF", text_options)
		else
			drawtext(40, 44, "ON", text_options)
		end
		
		j = 5
		gosub selectone
		if values_vtx[j] = 1
			drawtext(100, 14, "RTC", text_options)
		elseif values_vtx[j] = 2
			drawtext(100, 14, "WTF", text_options)
		elseif values_vtx[j] = 3
			drawtext(100, 14, "SA", text_options)
		elseif values_vtx[j] = 4
			drawtext(100, 14, "TR", text_options)
		else
			drawtext(100, 14, "OOR", text_options)
		end
		
		j = 6
		gosub selectone
		drawnumber(100, 24, values_vtx[j], text_options + LEFT)
		
		j = 7
		gosub selectone
		if values_vtx[j]
			drawtext(100, 34, "ON", text_options)
		else
			drawtext(100, 34, "OFF", text_options)
		end
	end
return


run:
	now = gettime()
	if (gState = PAGE_SAVING) & (saveTS + 150 < now)
		if saveRetries < 2 
			gosub SetupPages
			gosub  saveSettings
		else
			rem  --- two retries and still no success
			gState = PAGE_DISPLAY
			saveTS = 0
		end 
	end


	if t_size > 0 
		gosub mspProcessTxQ
	end

	rem  -- navigation

	if Event = EVT_MENU_LONG
		if gState # MENU_DISP
			gState = MENU_DISP
			killevents(Event)
		end
	elseif gState = MENU_DISP
		if Event = EVT_EXIT_BREAK
			gState = PAGE_DISPLAY
		end
	elseif gState <= PAGE_DISPLAY
		if  Event = EVT_MENU_BREAK 
			gosub incPage
		elseif Event = EVT_UP_FIRST
			gosub decLine
		elseif Event = EVT_DOWN_FIRST	 
			gosub incLine
		elseif Event = EVT_RIGHT_FIRST 
			page = currentPage
			gosub SetupPages
			gosub check_values
			if v_flag
				gState = EDITING
			end
		end
		rem   -- editing value
	elseif gState = EDITING
		if Event = EVT_EXIT_BREAK
			gState = PAGE_DISPLAY
		elseif Event = EVT_UP_FIRST
			gosub incValue 
		elseif Event = EVT_DOWN_FIRST
			gosub decValue 
		end
	end

	page = currentPage
	gosub SetupPages
	gosub check_values 

	if v_flag = 0
		gosub requestPage 
	end

	drawclear()
	if getvalue("RSSI") = 0 
		drawtext(30, 55, "No Telemetry", BLINK)
		gosub invalidatePages
	end

	if gState = MENU_DISP
		gosub drawScreen
		popresult = popup("set\0reload\0reboot", 0b111, 8)
		Event = 0
		if popresult # 0
			gState = PAGE_DISPLAY
		end
		if popresult = 1
			gosub saveSettings
		elseif popresult = 2
			gosub invalidatePages
		elseif popresult = 3
			gosub rebootFC
		end
	elseif gState = PAGE_SAVING
		drawrectangle(12,12,104,30)
		drawtext(16,22,"Saving...",DBLSIZE + BLINK)
		rem alert("Saving", 1)
	elseif gState = PAGE_DISPLAY
		gosub drawScreen
	elseif  gState = EDITING
		gosub drawScreen
	elseif gState = TEST
		gosub drawTestScreen
	end

	if Event = EVT_EXIT_BREAK
		gState = PAGE_DISPLAY
	elseif Event = EVT_LEFT_FIRST
		if DEBUG_MODE
			gState = TEST
		end
	end

	gosub mspPollReply
	gosub processMspReply

stop

done:
	finish