char* rtm_to_string(int code);
char* tca_to_string(uint16_t type);

void Bin2Hex(char *dest, int sizeof_dest, const uint8_t *src, int len, uint32_t PrintFlags);
void LogBuffer(char *Message, const uint8_t* pData, int DataSize);


