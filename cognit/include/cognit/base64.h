/*******************************************************/ /***
*	\file  ${file_name}
*	\brief HTTP client
*
*	Compiler  :  \n
*	Copyright : Samuel Pérez \n
*	Target    :  \n
*
*	\version $(date) ${user} $(remarks)
***********************************************************/
#ifndef _BASE64_H_
#define _BASE64_H_

#ifdef __cplusplus
extern "C" {
#endif

/*******************************************************/ /**
 * @brief Fuction to know the length of the encoded string
 * based on the size of the string
 * 
 * @param len Size of the plain string
 * @return int Size of the encoded string
***********************************************************/
int base64_encode_len(int len);

/*******************************************************/ /**
 * @brief Function to encode a string to base64
 * 
 * @param coded_dst Coded string
 * @param plain_src Plain string
 * @param len_plain_src Size of the plain string
 * @return int Size of the encoded string
***********************************************************/
int base64_encode(char* coded_dst, const char* plain_src, int len_plain_src);

/*******************************************************/ /**
 * @brief Function to know the length of the decoded string
 * 
 * @param coded_src Coded string
 * @return int Size of the decoded string
***********************************************************/
int base64_decode_len(const char* coded_src);

/*******************************************************/ /**
 * @brief Function to decode a string from base64
 * 
 * @param plain_dst Plain string
 * @param coded_src Coded string
 * @return int Size of the decoded string
***********************************************************/
int base64_decode(char* plain_dst, const char* coded_src);

#ifdef __cplusplus
}
#endif

#endif //_BASE64_H_