function data =sifreadnk(file)
f=fopen(file,'r');
if f < 0
   error('Could not open the file.');
end
if ~isequal(fgetl(f),'Andor Technology Multi-Channel File')
   fclose(f);
   error('Not an Andor SIF image file.');
end
skipLines(f,1);
data=readSection(f);
fclose(f);


%Read a file section.
%
% f      File handle
% info   Section data
% next   Flags if another section is available
%
function info=readSection(f)
o=fscanf(f,'%d',6); %% scan over the 6 Bytes
info.temperature=o(6); %o(6)
skipBytes(f,10);%% skip the space (why 10 not 11?)
%skipLines(f,1);
%info.whatisthis=readLine(f)
o=fscanf(f,'%f',5);%% Scan the next 5 bytes
info.delayExpPeriod=o(2);
info.exposureTime=o(3);
info.accumulateCycles=o(5);
info.accumulateCycleTime=o(4);
skipBytes(f,2); %% skip 2 more bytes
o=fscanf(f,'%f',2);
info.stackCycleTime=o(1);
info.pixelReadoutTime=o(2);
o=fscanf(f,'%d',3);
info.gainDAC=o(3);
skipLines(f,1);
info.detectorType=readLine(f);
%skipLines(f,1);
%info.whatisthis=readLine(f)
info.detectorSize=fscanf(f,'%d',[1 2]); %% I think everythings ok to here
info.fileName=readString(f);
%skipLines(f,4); %% changed this from 26 from Ixon camera now works for Newton. %%%%%%%%%%%%%%%%%%%%%%% ALL YOU NEED TO CHANGE

skipUntil(f,'65538')
skipUntil(f,'65538')

% Added the following to extract the center wavelength and grating
o=fscanf(f,'%f',8);
info.centerWavelength = o(4);
info.grating = round(o(7));

%skipLines(f,10); % added this in
skipUntil(f,'65539')
skipUntilChar(f,'.')
backOneLine(f)

o=fscanf(f,'%f',4);
info.minWavelength = o(1);
info.stepWavelength = o(2);
info.step1Wavelength = o(3);
info.step2Wavelength = o(4);
info.maxWavelength = info.minWavelength + info.detectorSize(1)*info.stepWavelength;

% Create wavelength, energy and frequency axes.
da = 1:(info.detectorSize(1));
info.axisWavelength = info.minWavelength + da.*(info.stepWavelength + da.*info.step1Wavelength + da.^2*info.step2Wavelength);
info.axisEnergy = convertUnits(info.axisWavelength,'nm','eV'); % energy in eV
info.axisGHz = convertUnits(info.axisWavelength,'nm','GHz');

%skipLines(f,6);
skipUntil(f,'Wavelength');
backOneLine(f)
backOneLine(f)


info.frameAxis=readString(f); %'Pixel number'
info.dataType=readString(f);  %'Counts' %% gets this from andor file
info.imageAxis=readString(f);  %'Pixel number' %% gets this from andor file
o=fscanf(f,'65541 %d %d %d %d %d %d %d %d 65538 %d %d %d %d %d %d',14); %% 14 is lines in o?
temp = o;
info.imageArea=[o(1) o(4) o(6);o(3) o(2) o(5)];
info.frameArea=[o(9) o(12);o(11) o(10)];
info.frameBins=[o(14) o(13)];
s=(1 + diff(info.frameArea))./info.frameBins;
z=1 + diff(info.imageArea(5:6));

info.kineticLength = o(5);
if prod(s) ~= o(8) || o(8)*z ~= o(7);
   fclose(f);
   error('Inconsistent image header.');
end
% for n=1:z                       % Had to comment this section for kinetic
%    o=readString(f);
%    if numel(o)
%       fprintf( '%s\n',o);      % comments
%    end
% end

skipLines(f,2+info.kineticLength); % changed from 2 to 2+info.kineticLength. This is the trick to get kinetic mode to work.

%for ii = 1:info.kineticLength
%    info.imageData=reshape(fread(f,prod(s)*z,'single=>single'),[s z]); %Switched z and s around to flip image 90 degrees
info.imageData = reshape(fread(f,prod(s)*z,'single=>single'),[s z]);
    %info.imageData{ii} =fread(f,prod(s)*z);
    %size(info.imageData(:,:,ii));
%end

o=readString(f);           % read the whole file.
if numel(o)
   fprintf('%s\n',o);      % If the file has no elements, then return error?
end




%Read a character string.
%
% f      File handle
% o      String
%
function o=readString(f)
n=fscanf(f,'%d',1);
if isempty(n) || n < 0 || isequal(fgetl(f),-1)
   fclose(f);
   error('Inconsistent string.');
end
o=fread(f,[1 n],'uint8=>char');


%Read a line.
%
% f      File handle
% o      Read line
%
function o=readLine(f)
o=fgetl(f);
if isequal(o,-1)
   fclose(f);
   error('Inconsistent image header.');
end
o=deblank(o);


%Skip bytes.
%
% f      File handle
% N      Number of bytes to skip
%
function skipBytes(f,N)
[ret,n]=fread(f,N,'uint8');
if n < N
   fclose(f);
   error('Inconsistent image header.');
end


%Skip lines.
%
% f      File handle
% N      Number of lines to skip
%
function skipLines(f,N)
for n=1:N
   if isequal(fgetl(f),-1)
      fclose(f);
      error('Inconsistent image header.');
   end
end





% Skip to the line starting with str.

function skipUntil(f,str)

ls = length(str);
stringFound = 0;
while ~stringFound
    % Read line
    s = readLine(f);

    if length(s)>=ls && strcmp(s(1:ls), str) % check if string found.
        stringFound = 1;
    else
        stringFound = 0;
    end
end

% Skip to the first incidence of the character c.
function skipUntilChar(f,c)
stringFound = 0;
while ~stringFound
    % Read line
    cread=fscanf(f,'%c',1);
    if cread==c
        stringFound=1;
    end
end


function backOneLine(f)
newLineFound = 0;
numTimes = 0;
while ~newLineFound
    fseek(f,-2,'cof');
    c=fscanf(f,'%c',1);
    newLineFound = c==10;
    numTimes = numTimes+1;
end
